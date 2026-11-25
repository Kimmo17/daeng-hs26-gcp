"""Erzeugt die synthetische Lieferung version=2026-12-14 aus version=2026-11-17.

Jede Lieferung ist ein vollständiger Stand (Snapshot) aller vier Listen, so wie sie bis dahin
abgetippt wurden: alte Zeilen bleiben, neue kommen dazu. Deshalb darf die Pipeline immer nur
die neueste Version auswerten, sonst zählt sie Zeilen doppelt.
Aufruf aus dem Repo-Ordner: python3 garage/tools/erzeuge_version_2026-12-14.py
SYNTHETISCH, Seed 1214. Keine Beobachtung der Garage.
"""
import csv, datetime as dt, math, random, sys
from pathlib import Path

random.seed(1214)
BASIS = Path(__file__).resolve().parent.parent / "data"
ALT, NEU = BASIS / "version=2026-11-17", BASIS / "version=2026-12-14"

def lesen(name):
    with open(ALT / name, newline="", encoding="utf-8") as f:
        r = csv.DictReader(f); return r.fieldnames, list(r)
def schreiben(name, felder, zeilen):
    NEU.mkdir(parents=True, exist_ok=True)
    with open(NEU / name, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=felder); w.writeheader(); w.writerows(zeilen)
def arbeitstage(start, n):
    t, d = [], start
    while len(t) < n:
        if d.weekday() < 5: t.append(d)
        d += dt.timedelta(1)
    return t
def plus_at(d, n):
    while n > 0:
        d += dt.timedelta(1)
        if d.weekday() < 5: n -= 1
    return d
def poisson(l):
    L, k, p = math.exp(-l), 0, 1.0
    while p > L: k += 1; p *= random.random()
    return k - 1

# --- Terminbuch: 4 weitere Wochen (KW 44-47), angehängt -----------------------------
felder, alt = lesen("ds01_terminbuch.csv")
texte = {"Service": ["Service", "Serv.", "grosser Service", "kl. Service", "Ölwechsel"],
         "Reparatur": ["Bremsen vorne", "Auspuff", "Kupplung", "Batterie", "Zahnriemen"],
         "Reifenwechsel": ["Räder", "Radwechsel", "Winterräder", "RW + einlagern"],
         "MFK-Vorbereitung": ["MFK", "MFK vorbereiten"]}
nr, seite, neu = int(alt[-1]["eintrag_nr"]), int(alt[-1]["buchseite"]), []
for d in arbeitstage(dt.date(2026, 10, 26), 20):
    seite += 1
    n_reg, n_rw = random.choice([7, 8, 8]), random.choice([3, 4, 5]) if d < dt.date(2026, 11, 9) else random.choice([1, 2])
    arten = random.choices(["Service", "Reparatur", "MFK-Vorbereitung"], [0.5, 0.38, 0.12], k=n_reg) + ["Reifenwechsel"] * n_rw
    zeiten = sorted(random.sample(["07:30", "08:00", "08:30", "09:00", "10:00", "10:30", "11:00", "13:30", "14:00", "14:30", "15:00", "15:30", "16:00"], len(arten)))
    for art, z in zip(arten, zeiten):
        nr += 1
        neu.append(dict(eintrag_nr=nr, buchseite=seite, datum=d.isoformat(), zeit=z, kunde_pseudo=f"K-{random.randint(1, 399):04d}",
                        arbeit_freitext=random.choice(texte[art]), status_vermerk=random.choices(["erl.", "", "verschoben"], [0.6, 0.36, 0.04])[0],
                        radiert="nein", nachgetragen="nein", auftragsart_codiert=art))
for i in random.sample(range(len(neu)), 4): neu[i]["arbeit_freitext"], neu[i]["auftragsart_codiert"] = "(unleserlich)", "unklar"
for i in random.sample(range(len(neu)), 5): neu[i]["radiert"] = "ja"
for i in random.sample(range(len(neu)), 3): neu[i]["zeit"] = neu[i]["zeit"].replace(":", ".")
schreiben("ds01_terminbuch.csv", felder, alt + neu)

# --- Reifenhotel: gleiche Sätze, Status nachgeführt, 3 neue Sätze ------------------
felder, rh = lesen("ds02_reifenhotel.csv")
offen = [r for r in rh if r["wechsel_herbst_2026"] == ""]
for r in random.sample(offen, 70): r["wechsel_herbst_2026"] = "erledigt"
for r in random.sample([r for r in rh if r["wechsel_herbst_2026"] == "Termin"], 15): r["wechsel_herbst_2026"] = "erledigt"
for k in range(3):
    rh.append(dict(satz_nr=f"RH-{190 + k:03d}", kunde_pseudo=f"K-{random.randint(1, 399):04d}", einlagerung_datum=(dt.date(2026, 11, 2) + dt.timedelta(k)).isoformat(),
                   eingelagert="Sommerräder", dimension="205/55 R16", lagerplatz=f"R6-{20 + k}", wechsel_herbst_2026="erledigt", bemerkung=""))
schreiben("ds02_reifenhotel.csv", felder, rh)

# --- Anfragen und Anrufe: 2 weitere Wochen (KW 49-50), angehängt --------------------
f_a, anfragen = lesen("data01_anfragen.csv"); f_c, anrufe = lesen("data02_anrufe.csv")
an = int(anfragen[-1]["anfrage_nr"][2:])
for d in arbeitstage(dt.date(2026, 11, 30), 10):
    n = poisson(14) + (4 if d.weekday() == 0 else 0); verpasst = sum(random.random() < 0.08 for _ in range(n)); voll = n > 17
    anrufe.append(dict(datum=d.isoformat(), anrufe_total=n, anrufe_verpasst=verpasst, anrufe_angenommen=n - verpasst))
    kanaele = [("Telefon", random.random() < (0.75 if voll else 0.95)) for _ in range(sum(random.random() < 0.65 for _ in range(n - verpasst)))]
    kanaele += [("Theke", random.random() < 0.95) for _ in range(poisson(2))] + [("E-Mail", True) for _ in range(poisson(0.6))]
    for kanal, erfasst in kanaele:
        if not erfasst: continue
        an += 1
        wunsch = plus_at(d, random.choice([0, 1, 1, 2, 2, 3, 4, 5]))
        versch = random.choices([0, 1, 2, 3], [0.6, 0.25, 0.1, 0.05])[0]
        erstes = plus_at(wunsch, versch); ja = random.random() < [0.97, 0.85, 0.7, 0.55][versch]
        anfragen.append(dict(anfrage_nr=f"A-{an:03d}", anfrage_datum=d.isoformat(), anfrage_zeit=f"{random.choice([7,8,9,10,11,13,14,15,16,17]):02d}:{random.choice(['05','20','35','50'])}",
                             kanal=kanal, auftragsart=random.choices(["Service", "Reparatur", "Reifenwechsel", "MFK-Vorbereitung"], [0.45, 0.4, 0.05, 0.1])[0],
                             wunschtag=wunsch.isoformat(), erster_angebotener_termin=erstes.isoformat(), angenommen="ja" if ja else "nein",
                             grund_ablehnung="" if ja else random.choice(["Termin zu spät", "unbekannt", "anderswo"])))
neue = [a for a in anfragen if a["anfrage_datum"] >= "2026-11-30"]
random.choice(neue)["erster_angebotener_termin"] = ""          # bekannter Erfassungsfehler, wie in Version 1
schreiben("data01_anfragen.csv", f_a, anfragen); schreiben("data02_anrufe.csv", f_c, anrufe)
print("geschrieben:", NEU)
