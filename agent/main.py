"""Triage-Agent: untersucht eine fehlgeschlagene Execution des Workflows und schreibt eine Diagnose.

Aufruf: python main.py <execution-id>        eine Diagnose, eine Zeile in ops.incidents
        python main.py --selftest             jedes Werkzeug einmal, zeigt fehlende Rollen

Der Agent liest, schliesst und schlägt vor. Er führt nichts aus, und er hat dafür auch kein
Werkzeug. Die eine Schreiboperation, die Zeile in ops.incidents, macht dieses Programm, nicht
das Modell.

Vier Teile, in dieser Reihenfolge: die Diagnose als Schema, die Anweisung an das Modell, der
Agent mit seinen Werkzeugen, und der Lauf, der am Ende die Zeile schreibt.
"""

import asyncio
import json
import logging
import os
import sys
import time
import uuid
from collections import defaultdict
from datetime import datetime, timezone
from typing import Literal

import google.auth
from google.adk.agents import LlmAgent
from google.adk.agents.run_config import RunConfig
from google.adk.integrations.bigquery import BigQueryCredentialsConfig, BigQueryToolset
from google.adk.integrations.bigquery.config import BigQueryToolConfig, WriteMode
from google.adk.runners import InMemoryRunner
from google.cloud import bigquery
from google.genai import types
from pydantic import BaseModel, Field

import tools

PROJECT = tools.PROJECT
REGION = tools.REGION
MODEL = os.environ.get("MODEL", "gemini-3.8-flash")
OPS_DATASET = os.environ.get("OPS_DATASET", "ops")
# Obergrenze für Modellaufrufe pro Diagnose. Ein Vorfall braucht 5 bis 20, die Grenze schützt
# vor einer Schleife, nicht vor Kosten: die entstehen durch die Werkzeugantworten im Prompt.
MAX_LLM_CALLS = int(os.environ.get("MAX_LLM_CALLS", "30"))
# Zeitbudget für den Lauf des Modells, in Sekunden. Läuft es ab, schreibt der Job trotzdem
# eine Zeile (Kategorie unklar, mit dem, was er bis dahin gelesen hat), statt am Task-Timeout
# des Jobs still zu sterben. Muss unter dem Task-Timeout des Cloud-Run-Jobs liegen.
TIME_BUDGET_SECONDS = int(os.environ.get("TIME_BUDGET_SECONDS", "600"))

# Das SDK warnt bei jeder Antwort mit einem Werkzeugaufruf, dass sie keinen Text enthält.
# Das ist hier der Normalfall, die Zeile hat keinen Wert.
logging.getLogger("google_genai.types").setLevel(logging.ERROR)


# 1. Die Diagnose. Das Modell muss genau diese Felder füllen, mit genau diesen Werten.
#    Eine Kategorie aus sechs, die Fakten getrennt von den Schlüssen, und die Konfidenz darf
#    nur hoch sein, wenn die Ursache gelesen wurde, nicht erschlossen.
class Diagnose(BaseModel):
    category: Literal["Konfigurationsfehler", "Code-Änderung", "Regel zu streng",
                      "Berechtigung", "Daten geändert", "unklar"]
    what_happened: str = Field(description="Was geschah, in zwei bis drei Sätzen: welcher Schritt, welcher Job, welche Meldung")
    where_to_look: list[str] = Field(description="Wo ein Mensch nachschaut: Execution, Logfilter, Tabelle, Scan")
    facts: list[str] = Field(description='Gelesene Fakten, jeder Eintrag "Fakt (Werkzeug)"')
    inferences: list[str] = Field(description="Schlüsse, die aus den Fakten folgen, aber nicht gelesen wurden")
    cause: str = Field(description="Die Ursache in einem Satz")
    proposed_fix: str = Field(description="Die vorgeschlagene Massnahme, als Vorschlag an einen Menschen")
    confidence: Literal["hoch", "mittel", "tief"] = Field(
        description="hoch nur, wenn die Ursache selbst in facts steht, nicht nur in inferences")


# 2. Die Anweisung. Sie beschreibt das Vorgehen eines Menschen bei einem Vorfall, nicht die
#    Vorfälle dieser Lektion. Nichts hier nennt eine Ursache.
INSTRUCTION = f"""Du untersuchst einen Vorfall in einer Datenpipeline. Projekt {PROJECT}, Region {REGION}.
Ein Cloud Workflow ({tools.WORKFLOW}) startet Cloud-Run-Jobs ({', '.join(tools.JOBS)}), die Daten nach
BigQuery laden und transformieren, und prüft die Daten mit einem Dataplex-Scan ({tools.DATASCAN}).
Du bekommst die ID einer fehlgeschlagenen Execution des Workflows.

Vorgehen:
1. Lies die Execution (get_workflow_execution) und bestimme den Schritt, der scheiterte, und die Meldung.
   Fehlt failed_step, weil der Workflow den Fehler weitergeworfen hat, folgt der Schritt aus der Meldung
   und der darin genannten Ressource.
2. Lies, was zu diesem Schritt gehört: den Job und seine Executions mit Logzeilen, oder den Scan mit
   seinen Regeln und Ergebnissen, oder den Workflow selbst.
3. Vergleiche mit der Historie: frühere Executions des Workflows und der Jobs, frühere Scan-Ergebnisse,
   Zeilen pro Partition.
4. Suche nach Änderungen der letzten Tage: Deployments (list_builds, get_job update_time und last_modifier),
   Audit-Log (get_admin_activity für Jobs, Workflow und Scan), Scan-Spezifikation, Load-Jobs mit ihrem
   Schreibmodus (get_load_jobs), DML in BigQuery.
5. Wähle die einfachste Erklärung, die alle Fakten deckt. Widerspricht eine Tatsache deinem Schluss,
   zum Beispiel ein erfolgreicher Lauf nach der vermuteten Ursache, nenne sie.

BigQuery (Location {REGION}): Frage `region-{REGION}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT immer mit
Zeitfilter `creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)` ab, nie mit SELECT *,
und verdichtet. Meistens reichen diese zwei Abfragen:
- Zeilen pro Partition von raw.trips:
  SELECT partition_id, total_rows, last_modified_time FROM `{PROJECT}.raw.INFORMATION_SCHEMA.PARTITIONS`
  WHERE table_name = 'trips' ORDER BY partition_id
- Was in den letzten 7 Tagen auf raw geschrieben hat, pro Tag, Tabelle, Art und Person:
  SELECT DATE(creation_time) AS tag, destination_table.table_id AS tabelle, job_type, statement_type,
    user_email, state, COUNT(*) AS jobs, MAX(creation_time) AS zuletzt
  FROM `region-{REGION}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
  WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
    AND destination_table.dataset_id = 'raw'
    AND (job_type = 'LOAD' OR statement_type IN ('INSERT','UPDATE','DELETE','MERGE','TRUNCATE_TABLE'))
  GROUP BY 1, 2, 3, 4, 5, 6 ORDER BY zuletzt DESC LIMIT 30

Ausgabe:
- facts: nur, was du mit einem Werkzeug gelesen hast, je "Fakt (Werkzeug)".
- inferences: was daraus folgt, aber nicht direkt gelesen wurde.
- confidence "hoch" nur, wenn die Ursache selbst in facts steht. Folgt sie nur aus inferences,
  höchstens "mittel".
- proposed_fix: nur, was einen früheren Zustand wiederherstellt (eine Rolle wieder setzen, den Job aus
  dem bekannten Code neu deployen, eine frühere Spezifikation zurückspielen) oder einen idempotenten
  Schritt wiederholt (der Workflow darf danach einmal laufen). Schlage keine Bereinigung von Daten vor,
  solange nicht belegt ist, dass der nächste Lauf sie nicht ohnehin ersetzt. Immer als Vorschlag an
  einen Menschen. Du führst nichts aus, du hast keine Werkzeuge dafür.
Antworte auf Deutsch."""


# 3. Der Agent: ein Modell, eine Anweisung, die Werkzeuge, das Schema. Das BigQuery-Werkzeug
#    kommt von ADK, mit Schreibsperre und einer Obergrenze pro Abfrage. Die anderen stehen in
#    tools.py.
def build_agent(stats: dict) -> LlmAgent:
    credentials, _ = google.auth.default()
    bq = BigQueryToolset(
        credentials_config=BigQueryCredentialsConfig(credentials=credentials),
        bigquery_tool_config=BigQueryToolConfig(
            write_mode=WriteMode.BLOCKED, compute_project_id=PROJECT, location=REGION,
            maximum_bytes_billed=1_000_000_000),
        tool_filter=["list_dataset_ids", "list_table_ids", "get_dataset_info", "get_table_info",
                     "execute_sql"])

    def before_model(callback_context, llm_request):
        stats["model_calls"] += 1
        stats["model_started"] = time.monotonic()

    def after_model(callback_context, llm_response):
        # Eine Logzeile pro Modellaufruf mit seiner Dauer, ohne die Werkzeuge: so sieht man im
        # Log, ob das Modell oder die Werkzeuge langsam sind.
        took = time.monotonic() - stats.get("model_started", time.monotonic())
        print(f"MODELL Aufruf {stats['model_calls']}: {took:.0f} s", flush=True)
        return None

    # Jeden Werkzeugaufruf mitschreiben: Name, Argumente, Länge und Anfang der Antwort. Das ist
    # der Nachweis, was der Agent gelesen hat, und landet in ops.incidents.
    def after_tool(tool, args, tool_context, tool_response):
        text = json.dumps(tool_response, default=str, ensure_ascii=False)
        stats["calls"].append({"tool": tool.name, "args": args, "chars": len(text),
                               "response_head": text[:300], "after_model_call": stats["model_calls"]})
        return None

    return LlmAgent(name="triage", model=MODEL, instruction=INSTRUCTION,
                    tools=[*map(tools.safe, tools.ALL), bq],
                    output_schema=Diagnose, output_key="diagnose",
                    before_model_callback=before_model, after_model_callback=after_model,
                    after_tool_callback=after_tool)


# 4. Der Lauf.
async def triage(execution_id: str, stats: dict) -> Diagnose:
    runner = InMemoryRunner(agent=build_agent(stats), app_name="triage")
    session = await runner.session_service.create_session(app_name="triage", user_id="job")
    msg = types.Content(role="user", parts=[types.Part(
        text=f"Fehlgeschlagene Execution von {tools.WORKFLOW}: {execution_id}")])
    # Token und Modellversion landen direkt in stats, damit sie auch bei einem Abbruch da sind.
    usage = stats["usage"]
    t0 = time.monotonic()
    async for ev in runner.run_async(user_id="job", session_id=session.id, new_message=msg,
                                     run_config=RunConfig(max_llm_calls=MAX_LLM_CALLS)):
        if ev.usage_metadata and not ev.partial:
            u = ev.usage_metadata
            usage["prompt"] = usage.get("prompt", 0) + (u.prompt_token_count or 0)
            usage["output"] = usage.get("output", 0) + (u.candidates_token_count or 0) + (u.thoughts_token_count or 0)
        stats["model_version"] = getattr(ev, "model_version", None) or stats["model_version"]
        for c in ev.get_function_calls():
            print(f"WERKZEUG {c.name} {json.dumps(dict(c.args or {}), ensure_ascii=False)[:200]}", flush=True)
    stats["seconds"] = round(time.monotonic() - t0, 1)
    # Die Diagnose liegt validiert im Session-State, unter dem output_key des Agenten.
    s = await runner.session_service.get_session(app_name="triage", user_id="job", session_id=session.id)
    return Diagnose.model_validate(s.state["diagnose"])


async def triage_with_budget(execution_id: str) -> tuple[Diagnose, dict]:
    # stats wird von den Callbacks gefüllt und bleibt auch dann erhalten, wenn der Lauf
    # abgebrochen wird. Darum liegt es hier und nicht in triage().
    stats = {"model_calls": 0, "calls": [], "usage": {}, "model_version": MODEL}
    t0 = time.monotonic()
    try:
        d = await asyncio.wait_for(triage(execution_id, stats), timeout=TIME_BUDGET_SECONDS)
    except asyncio.TimeoutError:
        stats["seconds"] = round(time.monotonic() - t0, 1)
        tools_used = [c["tool"] for c in stats["calls"]]
        print(f"ZEITBUDGET {TIME_BUDGET_SECONDS} s überschritten nach {stats['model_calls']} "
              f"Modellaufrufen und {len(tools_used)} Werkzeugaufrufen", flush=True)
        d = Diagnose(
            category="unklar", confidence="tief",
            what_happened=(f"Die Triage hat ihr Zeitbudget von {TIME_BUDGET_SECONDS} Sekunden überschritten, "
                           f"nach {stats['model_calls']} Modellaufrufen und {len(tools_used)} Werkzeugaufrufen. "
                           "Es liegt keine Diagnose vor."),
            where_to_look=[f"Werkzeuge bis zum Abbruch: {', '.join(tools_used) or 'keine'}",
                           "tool_calls dieser Zeile: Argumente und Anfang jeder Antwort",
                           "Log der triage-Execution: Dauer pro Modellaufruf (Zeilen MODELL)"],
            facts=[], inferences=[],
            cause="Keine Diagnose, Zeitbudget überschritten.",
            proposed_fix=("Triage nochmals starten. Bleibt es dabei, die Execution von Hand prüfen, "
                          "tool_calls zeigt, was der Agent schon gelesen hat."))
    return d, stats


def wait_until_finished(execution_id: str, max_seconds: int = 120):
    # Startet der Workflow diesen Job in seinem Fehlerzweig, ist die Execution einen Moment lang
    # noch ACTIVE. Erst wenn sie beendet ist, steht der Fehler drin.
    deadline = time.monotonic() + max_seconds
    while time.monotonic() < deadline:
        ex = tools.safe(tools.get_workflow_execution)(execution_id)
        if ex.get("state") not in (None, "ACTIVE"):
            return
        time.sleep(5)


def print_report(d: Diagnose, stats: dict):
    print("=" * 70)
    print(f"Kategorie: {d.category}   Konfidenz: {d.confidence}")
    print(f"Was geschah: {d.what_happened}")
    print(f"Ursache: {d.cause}")
    print(f"Vorschlag: {d.proposed_fix}")
    print("Wo nachschauen:", *[f"  - {x}" for x in d.where_to_look], sep="\n")
    print("Fakten:", *[f"  - {x}" for x in d.facts], sep="\n")
    print("Schlüsse:", *[f"  - {x}" for x in d.inferences], sep="\n")
    print("=" * 70)
    per_tool = defaultdict(lambda: [0, 0])
    for c in stats["calls"]:
        per_tool[c["tool"]][0] += 1
        per_tool[c["tool"]][1] += c["chars"]
    print(f"Werkzeuge (Aufrufe, Zeichen), {stats['model_calls']} Modellaufrufe:")
    for name, (n, chars) in sorted(per_tool.items(), key=lambda x: -x[1][1]):
        print(f"  {name:28s} {n:2d}  {chars:7d}")
    print(f"Token: prompt={stats['usage'].get('prompt', 0)} output={stats['usage'].get('output', 0)}  "
          f"Dauer={stats['seconds']} s  Modell={stats['model_version']}")


SCHEMA = [
    bigquery.SchemaField("incident_id", "STRING", "REQUIRED"),
    bigquery.SchemaField("workflow_execution", "STRING", "REQUIRED"),
    bigquery.SchemaField("created_at", "TIMESTAMP", "REQUIRED"),
    bigquery.SchemaField("category", "STRING"),
    bigquery.SchemaField("what_happened", "STRING"),
    bigquery.SchemaField("where_to_look", "STRING", "REPEATED"),
    bigquery.SchemaField("facts", "STRING", "REPEATED"),
    bigquery.SchemaField("inferences", "STRING", "REPEATED"),
    bigquery.SchemaField("cause", "STRING"),
    bigquery.SchemaField("proposed_fix", "STRING"),
    bigquery.SchemaField("confidence", "STRING"),
    bigquery.SchemaField("model_version", "STRING"),
    bigquery.SchemaField("tool_calls", "JSON"),
    bigquery.SchemaField("prompt_tokens", "INT64"),
    bigquery.SchemaField("output_tokens", "INT64"),
    bigquery.SchemaField("duration_seconds", "FLOAT64"),
    bigquery.SchemaField("status", "STRING"),
    bigquery.SchemaField("closed_by", "STRING"),
    bigquery.SchemaField("closed_at", "TIMESTAMP"),
]


def ensure_table(client: bigquery.Client) -> str:
    # Das Dataset ops legt ein Mensch an (Lektion 4, Schritt 4). Die Tabelle darf der Job anlegen,
    # er hat auf ops Schreibrecht, sonst nirgends.
    table = bigquery.Table(f"{PROJECT}.{OPS_DATASET}.incidents", schema=SCHEMA)
    client.create_table(table, exists_ok=True)
    return table.table_id


def write_row(execution_id: str, d: Diagnose, stats: dict):
    client = bigquery.Client(project=PROJECT, location=REGION)
    table_id = f"{PROJECT}.{OPS_DATASET}.incidents"
    ensure_table(client)
    row = {"incident_id": str(uuid.uuid4()), "workflow_execution": execution_id,
           "created_at": datetime.now(timezone.utc).isoformat(), **d.model_dump(),
           "model_version": stats["model_version"],
           "tool_calls": json.loads(json.dumps(
               [{k: c[k] for k in ("tool", "args", "chars", "response_head")} for c in stats["calls"]],
               default=str)),
           "status": "offen",
           "prompt_tokens": stats["usage"].get("prompt", 0),
           "output_tokens": stats["usage"].get("output", 0),
           "duration_seconds": stats["seconds"]}
    # Load-Job statt Streaming: Zeilen aus dem Streaming-Puffer liessen sich eine Weile nicht
    # per UPDATE schliessen, und schliessen ist der Zweck dieser Tabelle.
    job = client.load_table_from_json([row], table_id, job_config=bigquery.LoadJobConfig(
        write_disposition="WRITE_APPEND", schema=SCHEMA))
    job.result()
    print(f"ops.incidents: Zeile {row['incident_id']} geschrieben, Status offen")


def selftest():
    """Jedes Werkzeug einmal unter der Identität des Jobs aufrufen: zeigt fehlende Rollen, bevor
    der erste Vorfall kommt."""
    calls = [("get_workflow", ()), ("list_workflow_executions", ()), ("get_job", (tools.JOBS[0],)),
             ("list_job_executions", (tools.JOBS[0],)), ("get_admin_activity", (tools.JOBS[0], 7)),
             ("get_admin_activity", (tools.DATASCAN, 7)), ("get_admin_activity", (tools.WORKFLOW, 7)),
             ("get_datascan", ()), ("list_builds", ()), ("get_load_jobs", ("trips",))]
    ex = tools.safe(tools.list_job_executions)(tools.JOBS[0]).get("executions") or []
    if ex:
        calls.append(("get_execution_log", (ex[0]["execution_name"],)))
    wf = tools.safe(tools.list_workflow_executions)().get("executions") or []
    if wf:
        calls.append(("get_workflow_execution", (wf[0]["execution_id"],)))
    for name, args in calls:
        r = tools.safe(getattr(tools, name))(*args)
        status = "ERROR " + r["error"] if isinstance(r, dict) and r.get("status") == "ERROR" else "OK"
        print(f"SELFTEST {name}{args}: {status}")
    client = bigquery.Client(project=PROJECT, location=REGION)
    for label, sql in [
        ("PARTITIONS", f"SELECT partition_id, total_rows FROM `{PROJECT}.raw.INFORMATION_SCHEMA.PARTITIONS` "
                       "WHERE table_name = 'trips'"),
        ("JOBS_BY_PROJECT", f"SELECT COUNT(*) AS n FROM `region-{REGION}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT "
                            "WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)")]:
        try:
            rows = list(client.query(sql).result())
            print(f"SELFTEST bigquery {label}: OK ({len(rows)} Zeilen)")
        except Exception as exc:  # noqa: BLE001
            print(f"SELFTEST bigquery {label}: ERROR {type(exc).__name__}: {str(exc)[:300]}")
    try:
        ensure_table(client)
        print("SELFTEST ops.incidents: OK")
    except Exception as exc:  # noqa: BLE001
        print(f"SELFTEST ops.incidents: ERROR {type(exc).__name__}: {str(exc)[:300]}")


def main():
    if len(sys.argv) != 2:
        print("Aufruf: main.py <execution-id> | --selftest", file=sys.stderr)
        sys.exit(2)
    if sys.argv[1] == "--selftest":
        selftest()
        return
    execution_id = sys.argv[1]
    wait_until_finished(execution_id)
    d, stats = asyncio.run(triage_with_budget(execution_id))
    print_report(d, stats)
    if os.environ.get("OPS_WRITE", "1") != "0":
        write_row(execution_id, d, stats)


if __name__ == "__main__":
    main()
