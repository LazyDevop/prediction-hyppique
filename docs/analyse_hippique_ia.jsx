import { useState, useRef } from "react";

/* ============ Palette ============ */
const C = {
  bg: "#0B1120", surface: "#131C2E", surface2: "#0F1728",
  line: "rgba(255,255,255,.08)", line2: "rgba(255,255,255,.16)",
  gold: "#E8B33C", goldDim: "rgba(232,179,60,.12)",
  green: "#3DD68C", red: "#E5533D", blue: "#5B9BD5",
  txt: "#E7E4DA", muted: "#8B93A7",
};

const TERRAINS = [
  ["1.08", "Très léger"], ["1.05", "Léger"], ["1.02", "Bon léger"], ["1", "Bon"],
  ["0.97", "Bon souple"], ["0.93", "Souple"], ["0.88", "Très souple"],
  ["0.83", "Collant"], ["0.77", "Lourd"], ["0.7", "Très lourd"],
  ["1.001", "Rapide (PSF)"], ["0.99", "Standard (PSF)"], ["0.95", "Lent (PSF)"],
];
const NIVEAUX = [
  ["5", "G I"], ["4.5", "G II"], ["4", "G III"], ["3.5", "G IV"], ["3", "Listed"],
  ["2.6", "Cat. A"], ["2.3", "Cat. B"], ["2", "Cat. C"], ["1.7", "Cat. D"],
  ["1.4", "Cat. E"], ["1.1", "Cat. F"], ["1", "Cat. G/H"],
];
const INCIDENTS = {
  "":   { label: "—",                 malus: 0,   chute: false },
  "T":  { label: "T · Tombé",         malus: 1.2, chute: true },
  "F":  { label: "F · Fell",          malus: 1.2, chute: true },
  "BD": { label: "BD · Brought Down", malus: 1.0, chute: true },
  "U":  { label: "U · Désarçonné",    malus: 1.0, chute: true },
  "A":  { label: "A · Arrêté",        malus: 0.7, chute: false },
  "RO": { label: "RO · Sorti piste",  malus: 0.7, chute: true },
  "RR": { label: "RR · Refus départ", malus: 0.7, chute: false },
  "D":  { label: "D · Disqualifié",   malus: 0.8, chute: false },
  "R":  { label: "R · Rétrogradé",    malus: 0.5, chute: false },
  "NR": { label: "NR · Non partant",  malus: 0,   chute: false, ignore: true },
};
const INCIDENT_OPTIONS = Object.keys(INCIDENTS).map((k) => [k, INCIDENTS[k].label]);
const RECENCE = {
  std: [1, 0.85, 0.7, 0.55, 0.42, 0.3],
  forme: [1, 0.65, 0.42, 0.28, 0.18, 0.12],
  flat: [1, 1, 1, 1, 1, 1],
};

const emptyPerf = () => ({ rank: "", part: "", incident: "", niveau: "2", dist: "", terr: "1" });
let seq = 0;
const newHorse = (d = {}) => ({
  id: ++seq,
  num: d.num ?? "",
  name: d.name || `Cheval ${seq}`,
  age: d.age ?? 5, poids: d.poids ?? 58, cote: d.cote ?? "",
  inedit: d.inedit || false,
  imported: d.imported || false,
  perfs: Array.from({ length: 6 }, (_, i) => {
    const p = (d.perfs || [])[i];
    return p
      ? { rank: p.rank ?? "", part: p.part ?? "", incident: p.incident ?? "", niveau: String(p.niveau ?? "2"), dist: p.dist ?? "", terr: String(p.terr ?? "1") }
      : emptyPerf();
  }),
});

/* ============ Moteur (identique à la V2 HTML) ============ */
function computeNote(p, cfg, malusInc) {
  const sb = Math.max(0, (p.part - p.rank + 1) / p.part);
  const dd = Math.abs(p.dist - cfg.dist);
  const cDist = dd <= 200 ? 1 : dd <= 500 ? 0.9 : 0.8;
  const dt = Math.abs(p.terr - cfg.terr);
  const cTerr = dt < 0.05 ? 1 : dt <= 0.1 ? 0.95 : 0.9;
  const cNiv = Math.min(1.5, Math.max(0.55, Math.sqrt(p.niveau / cfg.niveau)));
  const inc = INCIDENTS[p.incident] || INCIDENTS[""];
  const malus = inc.malus * (malusInc != null ? malusInc : 1);
  return Math.max(0, sb * cNiv * cDist * cTerr - malus);
}

function runModel(horses, cfg, prm) {
  const parsed = horses.map((h) => {
    const perfs = h.perfs
      .map((p) => ({
        rank: parseFloat(p.rank), part: parseFloat(p.part),
        incident: p.incident || "",
        niveau: parseFloat(p.niveau) || 1, dist: parseFloat(p.dist) || 0,
        terr: parseFloat(p.terr) || 1,
      }))
      .filter((p) => {
        const inc = INCIDENTS[p.incident] || INCIDENTS[""];
        if (inc.ignore) return false;                       // NR → ignoré
        const hasRank = isFinite(p.rank) && isFinite(p.part) && p.part >= 2;
        return hasRank || p.incident !== "";                // rang OU incident
      })
      .map((p) => {
        const hasRank = isFinite(p.rank) && isFinite(p.part) && p.part >= 2;
        const part = isFinite(p.part) && p.part >= 2 ? p.part : 12;
        return { ...p, part, rank: hasRank ? Math.min(p.rank, p.part) : part };
      });
    const cote = parseFloat(h.cote);
    const numV = parseFloat(h.num);
    return {
      name: h.name || "Sans nom",
      num: isFinite(numV) ? numV : null,
      age: parseFloat(h.age) || 5,
      poids: parseFloat(h.poids) || 0,
      cote: isFinite(cote) && cote > 1 ? cote : null, perfs,
      inedit: !!h.inedit,
    };
  });

  const pl = parsed.filter((h) => h.poids > 0).map((h) => h.poids);
  const avgPoids = pl.length ? pl.reduce((a, b) => a + b, 0) / pl.length : 0;

  const res = parsed.map((h) => {
    // Poids et âge sont connus même pour un cheval sans performance :
    // ils sont donc toujours calculés (appliqués plus bas selon le cas).
    let cPoids = 1;
    if (h.poids > 0 && avgPoids > 0)
      cPoids = Math.min(1.15, Math.max(0.85, 1 - (prm.sensPoids / 100) * (h.poids - avgPoids)));
    let cAge = 1;
    if (h.age < prm.ageMin) cAge = Math.max(0.8, 1 - 0.05 * (prm.ageMin - h.age));
    if (h.age > prm.ageMax) cAge = Math.max(0.8, 1 - 0.05 * (h.age - prm.ageMax));

    if (!h.perfs.length)
      return { ...h, forme: 0, cPoids, cAge, ecart: 0, nPerfs: 0, score: 0, nChutes: 0, tauxChute: 0 };
    const w = prm.recence;
    let swn = 0, sw = 0;
    const notes = h.perfs.map((p, i) => {
      const n = computeNote(p, cfg, prm.malusInc);
      swn += n * w[i]; sw += w[i];
      return n;
    });
    const forme = swn / sw;
    const mean = notes.reduce((a, b) => a + b, 0) / notes.length;
    const ecart = Math.sqrt(notes.reduce((a, n) => a + (n - mean) ** 2, 0) / notes.length);
    const nChutes = h.perfs.filter((p) => (INCIDENTS[p.incident] || INCIDENTS[""]).chute).length;
    return { ...h, forme, cPoids, cAge, ecart, nPerfs: h.perfs.length, score: 0,
             nChutes, tauxChute: nChutes / h.perfs.length };
  });

  // Lissage bayésien + traitement des chevaux sans performance
  const withData = res.filter((r) => r.nPerfs > 0);
  const meanForme = withData.length
    ? withData.reduce((a, r) => a + r.forme, 0) / withData.length : 0;
  // Si personne n'a de perf (course de débutants), on part d'une base 1 pour
  // que l'âge et le poids restent différenciants au lieu de tout écraser à 0.
  const base = meanForme > 0 ? meanForme : 1;
  res.forEach((r) => {
    if (r.nPerfs > 0) {
      const f = (r.nPerfs * r.forme + prm.shrink * meanForme) / (r.nPerfs + prm.shrink);
      r.score = f * r.cPoids * r.cAge;
    } else if (r.inedit) {
      // Inédit : l'absence de course est un FAIT. Âge et poids s'appliquent.
      r.score = base * prm.coefInedit * r.cPoids * r.cAge;
    } else {
      // Données non saisies : on ne sait rien, aucun ajustement.
      r.score = base * 0.6;
    }
  });

  // Partants + outsiders virtuels
  const nE = res.length;
  const nbPart = isFinite(cfg.partants) && Math.round(cfg.partants) > nE ? Math.round(cfg.partants) : nE;
  const nVirt = nbPart - nE;
  const meanScore = res.reduce((a, r) => a + r.score, 0) / Math.max(1, nE);
  const virtScore = Math.max(meanScore * 0.6, 0.0001);

  const pow = res.map((r) => Math.pow(Math.max(r.score, 0.0001), prm.k));
  const vPow = Math.pow(virtScore, prm.k);
  const sum = pow.reduce((a, b) => a + b, 0) + nVirt * vPow;
  res.forEach((r, i) => (r.prob = sum > 0 ? pow[i] / sum : 0));
  const vProb = sum > 0 ? vPow / sum : 0;

  // Harville Top1/2/3
  const P = res.map((r) => r.prob).concat(Array(nVirt).fill(vProb));
  const n = P.length;
  res.forEach((r, i) => {
    let p2 = 0, p3 = 0;
    for (let j = 0; j < n; j++) {
      if (j === i) continue;
      const d1 = 1 - P[j];
      if (d1 > 1e-9) p2 += (P[j] * P[i]) / d1;
      for (let k = 0; k < n; k++) {
        if (k === i || k === j) continue;
        const d2 = 1 - P[j] - P[k];
        if (d1 > 1e-9 && d2 > 1e-9) p3 += P[j] * (P[k] / d1) * (P[i] / d2);
      }
    }
    r.pTop1 = P[i]; r.pTop2 = Math.min(1, P[i] + p2); r.pTop3 = Math.min(1, P[i] + p2 + p3);
  });

  // Value + Kelly
  let sInv = 0, nC = 0;
  res.forEach((r) => {
    if (r.cote) {
      sInv += 1 / r.cote; nC++;
      r.pImp = 1 / r.cote;
      r.value = r.prob * r.cote - 1;
      const kelly = (r.prob * r.cote - 1) / (r.cote - 1);
      r.stake = kelly > 0 ? prm.bank * kelly * prm.kellyFrac : 0;
    } else { r.pImp = null; r.value = null; r.stake = 0; }
  });
  const overround = nC === nE && nC > 0 ? sInv - 1 : null;

  // ====== COMBINAISONS ======
  const rank = res.map((_, i) => i).sort((a, b) => P[b] - P[a]);
  const label = (ids) => ({
    nums: ids.map((x) => (res[x].num != null ? res[x].num : "?")),
    names: ids.map((x) => res[x].name),
  });

  // --- Énumération exacte (Plackett-Luce) : paris à ordre et désordre ---
  const enumerate = (len, poolSize) => {
    if (nE < len) return { ordre: [], desordre: [] };
    const ids = rank.slice(0, Math.min(poolSize, nE));
    const tuples = [];
    const rec = (chosen) => {
      if (chosen.length === len) {
        let p = 1, d = 1;
        for (const x of chosen) { p *= P[x] / d; d -= P[x]; if (d <= 1e-9) return; }
        tuples.push({ ids: chosen.slice(), p });
        return;
      }
      for (const x of ids) if (!chosen.includes(x)) rec([...chosen, x]);
    };
    rec([]);
    const ordre = tuples.slice().sort((a, b) => b.p - a.p).slice(0, 3)
      .map((t) => ({ ...label(t.ids), p: t.p }));
    // désordre = somme des permutations d'une même combinaison
    const agg = new Map();
    tuples.forEach((t) => {
      const k = t.ids.slice().sort((a, b) => a - b).join("-");
      const cur = agg.get(k);
      if (cur) cur.p += t.p;
      else agg.set(k, { ids: t.ids.slice().sort((a, b) => P[b] - P[a]), p: t.p });
    });
    const desordre = [...agg.values()].sort((a, b) => b.p - a.p).slice(0, 3)
      .map((t) => ({ ...label(t.ids), p: t.p }));
    return { ordre, desordre };
  };
  const couple = enumerate(2, 8);
  const tierce = enumerate(3, 7);
  const quarte = enumerate(4, 7);
  const quinte = enumerate(5, 7);

  // --- Monte-Carlo : paris "parmi les k premiers" (couplé placé, 2 sur 4) ---
  // L'énumération exacte est impraticable ici : on simule des courses en
  // tirant les places sans remise, proportionnellement aux probabilités.
  const NSIM = 20000;
  const mcP3 = new Map(), mcP4 = new Map();
  const top4 = new Array(nE).fill(0);
  const w2 = new Float64Array(n);
  const bump = (m, k, ids) => {
    const cur = m.get(k);
    if (cur) cur.c++; else m.set(k, { c: 1, ids });
  };
  for (let s = 0; s < NSIM; s++) {
    for (let i = 0; i < n; i++) w2[i] = P[i];
    let total = 1;
    const ord = [];
    for (let pos = 0; pos < Math.min(4, n); pos++) {
      let r = Math.random() * total, pick = -1;
      for (let j = 0; j < n; j++) {
        if (w2[j] <= 0) continue;
        r -= w2[j];
        if (r <= 0) { pick = j; break; }
      }
      if (pick < 0) for (let j = n - 1; j >= 0; j--) if (w2[j] > 0) { pick = j; break; }
      if (pick < 0) break;
      ord.push(pick); total -= w2[pick]; w2[pick] = 0;
    }
    const t3 = ord.slice(0, 3).filter((x) => x < nE);
    const t4 = ord.slice(0, 4).filter((x) => x < nE);
    t4.forEach((x) => top4[x]++);
    for (let i = 0; i < t3.length; i++)
      for (let j = i + 1; j < t3.length; j++) {
        const a = Math.min(t3[i], t3[j]), b = Math.max(t3[i], t3[j]);
        bump(mcP3, a + "-" + b, [a, b]);
      }
    for (let i = 0; i < t4.length; i++)
      for (let j = i + 1; j < t4.length; j++) {
        const a = Math.min(t4[i], t4[j]), b = Math.max(t4[i], t4[j]);
        bump(mcP4, a + "-" + b, [a, b]);
      }
  }
  const mcBest = (m) => [...m.values()].sort((a, b) => b.c - a.c).slice(0, 3)
    .map((e) => ({ ...label(e.ids.slice().sort((x, y) => P[y] - P[x])), p: e.c / NSIM }));
  const couplePlace = mcBest(mcP3);
  const deuxSur4 = mcBest(mcP4);
  res.forEach((r, i) => (r.pTop4 = top4[i] / NSIM));

  res.sort((a, b) => b.score - a.score);
  return { rows: res, overround, nbPart, nVirt, couple, tierce, quarte, quinte, couplePlace, deuxSur4 };
}

/* ============ Extraction IA depuis une image ============ */
const PROMPT = `Tu lis une fiche de cheval de course hippique (capture d'écran d'un site comme Geny, France Galop, PMU...).
Extrais les informations et réponds UNIQUEMENT avec un JSON valide, sans aucun texte autour, sans backticks, au format exact :
{"name":string,"num":number|null,"age":number|null,"poids":number|null,"cote":number|null,"perfs":[{"rank":number|null,"part":number|null,"incident":string,"niveau":number,"dist":number|null,"terr":number}]}

Règles :
- "num" = numéro de dossard du cheval si visible (ex: "101 - PASSAGE VALLET" -> 101). Attention : sur certains sites (ex. Genybet), ce numéro en tête de fiche peut parfois être élevé (ex. 604) et ne pas correspondre au vrai numéro de course PMU du jour — reste plausible mais à vérifier par l'utilisateur, ne pas le sur-interpréter comme certain.
- "poids" = poids porté / du jockey en kg (ex: "57 KG" -> 57).
- "perfs" = les courses de l'historique, triées de la PLUS RÉCENTE à la plus ancienne, maximum 6.
- "rank" = place obtenue (nombre). Sur les tableaux de performances (colonne "Rq"/Rang), un incident apparaît souvent directement comme une LETTRE à la place du chiffre (ex. "A" = Arrêté, "D" = Disqualifié, "T" = Tombé) — reconnais-la comme incident, mets rank=null.
- "incident" : code d'incident d'obstacle si la musique contient une lettre. Correspondances : T=Tombé, F=Fell, BD=Brought Down/tombé par un autre, U=désarçonné, A=Arrêté, RO=sorti de piste, RR=refus de partir, D=Disqualifié, R=Rétrogradé, NR=non partant. Sinon chaîne vide "". Dans une musique française, "0" = non placé (rank=10, incident=""), "T"/"A"/"D" etc = incident.
- "part" = nombre de partants de cette course. null si absent de la fiche.
- "dist" = distance en mètres.
- "terr" : échelle GAZON officielle France Galop (10 niveaux, du plus rapide au plus lourd) : très léger=1.08, léger=1.05, bon léger=1.02, bon=1, bon souple=0.97, souple=0.93, très souple=0.88, collant=0.83, lourd=0.77, très lourd=0.7. Échelle SABLE FIBRÉ/PSF distincte (Cagnes-sur-Mer, Deauville PSF...) : rapide=1.001, standard=0.99, lent=0.95. Ne confonds pas les deux échelles. Attention : "léger" = sol sec et ferme (rapide), PAS souple. "Super lourd" n'existe pas officiellement : si tu le lis, mets très lourd=0.7. Inconnu=1.
- "niveau" : Groupe I=5, Groupe II=4.5, Groupe III=4, Groupe IV=3.5, Listed=3. En dessous, les courses ordinaires (galop et trot) sont classées par LETTRE de A à G/H (A = la plus relevée) : Catégorie A=2.6, B=2.3, C=2, D=1.7, E=1.4, F=1.1, G ou H=1. Une "Course B" est cette Catégorie B (bon niveau intermédiaire), PAS une "Breeders Course" (terme non officiel). "Cond." (course à conditions) ou lettre inconnue=2. "Réclamer"/"À Réc."/claiming (les chevaux peuvent être achetés après course) = niveau modeste, mets 1.4 sauf indication contraire.
- Tout champ illisible ou absent : null (sauf terr et niveau qui ont des défauts).`;

const RACE_PROMPT = `Tu lis la capture d'écran d'un PROGRAMME de course hippique (liste des partants, type Geny/PMU/Equidia).
Extrais les informations et réponds UNIQUEMENT avec un JSON valide, sans aucun texte autour, sans backticks, au format exact :
{"hippo":string,"dist":number|null,"terr":number,"niveau":number,"partants":number|null,"horses":[{"num":number|null,"name":string,"age":number|null,"poids":number|null,"cote":number|null,"perfs":[{"rank":number|null,"incident":string}]}]}

Règles :
- "num" = numéro de dossard (colonne N°).
- "hippo" = nom de l'hippodrome. "dist" = distance en mètres (ex: "1,400 m" -> 1400).
- "terr" : échelle GAZON officielle (10 niveaux) : très léger=1.08, léger=1.05, bon léger=1.02, bon=1, bon souple=0.97, souple=0.93, très souple=0.88, collant=0.83, lourd=0.77, très lourd=0.7. Échelle SABLE FIBRÉ/PSF distincte : rapide=1.001, standard=0.99, lent=0.95. "Léger" = sol ferme et rapide, PAS souple. "Super lourd" n'existe pas officiellement (mets très lourd=0.7). Inconnu=1.
- "niveau" : Groupe I=5, Groupe II=4.5, Groupe III=4, Groupe IV=3.5, Listed=3. Courses ordinaires classées par LETTRE de A à G/H (A=la plus relevée, valable galop ET trot) : Catégorie A=2.6, B=2.3, C=2, D=1.7, E=1.4, F=1.1, G/H=1. "Cond."/handicap/lettre inconnue=2. "Réclamer"/"À Réc." (claiming, chevaux achetables après course) = niveau modeste, 1.4 sauf indication contraire.
- "partants" = nombre total de chevaux au départ (compte les lignes du tableau si non indiqué).
- Pour chaque cheval : "age" depuis la colonne S/A (ex: "M2"=2 ans, "F3"=3 ans, "H5"=5 ans). "poids" en kg. "cote" = la cote la plus récente visible (colonne Live sinon Réf.).
- "perfs" = la musique décodée, de la plus récente à la plus ancienne, maximum 6. Chaque élément : {"rank":place,"incident":code}. Un chiffre -> {"rank":ce chiffre,"incident":""}. "0" -> {"rank":10,"incident":""}. Une lettre d'incident -> {"rank":null,"incident":code} avec code parmi T,F,BD,U,A,RO,RR,D,R,NR (T=tombé, A=arrêté, D=disqualifié, etc). Ex: "1p T Ap" -> [{"rank":1,"incident":""},{"rank":null,"incident":"T"},{"rank":null,"incident":"A"}].
- Tout champ illisible ou absent : null.`;

async function extractFromImage(base64, mediaType, prompt) {
  const isPdf = mediaType === "application/pdf";
  const fileBlock = isPdf
    ? { type: "document", source: { type: "base64", media_type: "application/pdf", data: base64 } }
    : { type: "image", source: { type: "base64", media_type: mediaType, data: base64 } };
  const resp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "claude-sonnet-4-6",
      max_tokens: 2000,
      messages: [{
        role: "user",
        content: [fileBlock, { type: "text", text: prompt }],
      }],
    }),
  });
  const data = await resp.json();
  const text = (data.content || []).filter((b) => b.type === "text").map((b) => b.text).join("\n");
  const clean = text.replace(/```json|```/g, "").trim();
  return JSON.parse(clean);
}

/* ============ Petits composants ============ */
const inp = {
  background: C.surface2, color: C.txt, border: `1px solid ${C.line2}`,
  borderRadius: 8, padding: "7px 9px", fontSize: 13, width: "100%",
  fontVariantNumeric: "tabular-nums",
};
const lbl = { display: "flex", flexDirection: "column", gap: 4, fontSize: 11, color: C.muted, textTransform: "uppercase", letterSpacing: 0.5 };
const btn = (bg, color, extra = {}) => ({
  background: bg, color, border: "none", borderRadius: 9, padding: "11px 18px",
  fontSize: 13, fontWeight: 700, cursor: "pointer", letterSpacing: 0.4, ...extra,
});
const pct = (x) => (x * 100).toFixed(1) + " %";
const pctFine = (x) => (x >= 0.01 ? (x * 100).toFixed(1) : (x * 100).toFixed(3)) + " %";

function ComboBlock({ title, combos, note }) {
  return (
    <div style={{ background: C.surface2, border: `1px solid ${C.line}`, borderRadius: 10, padding: "9px 11px" }}>
      <div style={{ color: C.gold, fontSize: 10, textTransform: "uppercase", letterSpacing: 0.7, marginBottom: 5 }}>{title}</div>
      {combos && combos.length ? combos.map((o, i) => (
        <div key={i} style={{ padding: "3px 0", borderBottom: i < combos.length - 1 ? `1px solid ${C.line}` : "none" }}>
          <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}>
            <span style={{ fontWeight: 800, fontSize: 15, letterSpacing: 0.5, flex: 1 }}>{o.nums.join(" · ")}</span>
            <span style={{ color: C.green, fontWeight: 700, fontSize: 12 }}>{pctFine(o.p)}</span>
          </div>
          <div style={{ fontSize: 9.5, color: C.muted, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{o.names.join(" · ")}</div>
        </div>
      )) : <div style={{ fontSize: 11, color: C.muted }}>Pas assez de partants</div>}
      {note && <div style={{ fontSize: 10, color: C.muted, marginTop: 5, fontStyle: "italic" }}>{note}</div>}
    </div>
  );
}

function Field({ label, children }) {
  return <label style={lbl}>{label}{children}</label>;
}

/* ============ Application ============ */
export default function App() {
  const [cfg, setCfg] = useState({ hippo: "Vincennes", dist: 2000, partants: "", terr: "1", niveau: "3" });
  const [prm, setPrm] = useState({ bank: 100, kellyFrac: 0.25, rec: "std", k: 3, sensPoids: 1, ageMin: 4, ageMax: 7, shrink: 2, coefInedit: 0.75, malusInc: 1 });
  const [horses, setHorses] = useState([newHorse(), newHorse()]);
  const [results, setResults] = useState(null);
  const [busy, setBusy] = useState(false);
  const [busyRace, setBusyRace] = useState(false);
  const [err, setErr] = useState("");
  const fileRef = useRef(null);
  const raceRef = useRef(null);

  const readB64 = (file) => new Promise((res, rej) => {
    const r = new FileReader();
    r.onload = () => res(r.result.split(",")[1]);
    r.onerror = () => rej(new Error("Lecture du fichier impossible"));
    r.readAsDataURL(file);
  });

  const upd = (id, f, v) => { setResults(null); setHorses(hs => hs.map(h => h.id === id ? { ...h, [f]: v } : h)); };
  const updPerf = (id, i, f, v) => {
    setResults(null);
    setHorses(hs => hs.map(h => h.id === id
      ? { ...h, perfs: h.perfs.map((p, j) => j === i ? { ...p, [f]: v } : p) } : h));
  };
  const remove = (id) => { setResults(null); setHorses(hs => hs.filter(h => h.id !== id)); };

  const onImportImage = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    setErr(""); setBusy(true);
    try {
      const base64 = await readB64(file);
      const d = await extractFromImage(base64, file.type || "image/png", PROMPT);
      setHorses(hs => [...hs, newHorse({
        name: d.name || undefined, num: d.num ?? "",
        age: d.age ?? undefined, poids: d.poids ?? undefined, cote: d.cote ?? "",
        perfs: (d.perfs || []).slice(0, 6), imported: true,
      })]);
      setResults(null);
    } catch (ex) {
      setErr("Extraction échouée : " + (ex.message || ex) + ". Réessayez avec une capture plus nette.");
    } finally { setBusy(false); }
  };

  const onImportRace = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    setErr(""); setBusyRace(true);
    try {
      const base64 = await readB64(file);
      const d = await extractFromImage(base64, file.type || "image/png", RACE_PROMPT);
      const terr = String(d.terr ?? "1");
      const niveau = String(d.niveau ?? "2");
      const dist = d.dist ?? 2000;
      const nbPart = d.partants ?? (d.horses || []).length ?? "";
      setCfg({ hippo: d.hippo || "Course importée", dist, partants: nbPart, terr, niveau });
      // La musique donne places et incidents ; distance/terrain/niveau des
      // courses passées sont supposés identiques à la course du jour (coef=1).
      setHorses((d.horses || []).map((h, idx) => newHorse({
        name: h.name || undefined, num: h.num ?? (idx + 1),
        age: h.age ?? undefined, poids: h.poids ?? undefined, cote: h.cote ?? "",
        imported: true,
        perfs: (h.perfs || []).slice(0, 6)
          .filter(p => (p.rank !== null && isFinite(p.rank)) || (p.incident && p.incident !== ""))
          .map(p => ({
            rank: (p.rank !== null && isFinite(p.rank)) ? p.rank : "",
            part: nbPart || 12,
            incident: p.incident || "",
            niveau, dist, terr
          })),
      })));
      setResults(null);
    } catch (ex) {
      setErr("Extraction du programme échouée : " + (ex.message || ex) + ". Réessayez avec une capture plus nette du tableau des partants.");
    } finally { setBusyRace(false); }
  };

  const calc = () => {
    if (!horses.length) return;
    setResults(runModel(horses, {
      hippo: cfg.hippo, dist: parseFloat(cfg.dist) || 2000,
      partants: parseFloat(cfg.partants),
      terr: parseFloat(cfg.terr), niveau: parseFloat(cfg.niveau),
    }, { ...prm, recence: RECENCE[prm.rec], bank: parseFloat(prm.bank) || 100, k: parseFloat(prm.k) || 3, shrink: Math.max(0, parseFloat(prm.shrink) || 0), coefInedit: parseFloat(prm.coefInedit) || 0.75, malusInc: parseFloat(prm.malusInc) >= 0 ? parseFloat(prm.malusInc) : 1 }));
  };

  const regTxt = (r) => r.inedit ? ["🐴 Inédit", C.blue]
    : r.nPerfs === 0 ? ["Données non saisies", C.muted]
    : r.nPerfs < 3 ? [`Historique court (${r.nPerfs})`, C.muted]
    : r.ecart < 0.12 ? ["Très régulier", C.green] : r.ecart < 0.22 ? ["Régulier", C.green]
    : r.ecart < 0.33 ? ["Moyen", C.gold] : ["Irrégulier", C.red];

  const reco = (r, i) => r.nPerfs === 0 && !r.inedit ? "Données non saisies"
    : r.value === null ? "Cote manquante"
    : r.value >= 0.15 && r.prob >= 0.07 ? "Value forte — jouable"
    : r.value > 0.05 ? "Léger avantage"
    : r.value > 0 ? "Avantage marginal"
    : i < 2 ? "Favori du modèle, cote trop courte" : "Pas d'avantage";

  return (
    <div style={{ background: C.bg, minHeight: "100vh", color: C.txt, padding: 14, fontFamily: "system-ui, sans-serif" }}>
      <div style={{ maxWidth: 1080, margin: "0 auto" }}>

        <header style={{ borderBottom: `2px solid ${C.gold}`, padding: "10px 0 18px", marginBottom: 18 }}>
          <h1 style={{ color: C.gold, fontSize: 22, letterSpacing: 0.5, textTransform: "uppercase", margin: 0 }}>
            Analyse Hippique <span style={{ color: C.txt }}>· IA</span>
          </h1>
          <div style={{ color: C.muted, fontSize: 13, marginTop: 3 }}>
            Importez le programme d'une course ou une fiche cheval — l'IA remplit les champs, vous validez, le moteur calcule.
          </div>
        </header>

        {/* Course cible */}
        <section style={{ background: C.surface, border: `1px solid ${C.line}`, borderRadius: 12, padding: 16, marginBottom: 16 }}>
          <div style={{ color: C.gold, fontSize: 12, textTransform: "uppercase", letterSpacing: 1, marginBottom: 10 }}>Course cible</div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit,minmax(130px,1fr))", gap: 10 }}>
            <Field label="Hippodrome"><input style={inp} value={cfg.hippo} onChange={e => setCfg({ ...cfg, hippo: e.target.value })} /></Field>
            <Field label="Distance (m)"><input style={inp} type="number" value={cfg.dist} onChange={e => setCfg({ ...cfg, dist: e.target.value })} /></Field>
            <Field label="Partants"><input style={inp} type="number" placeholder="auto" value={cfg.partants} onChange={e => setCfg({ ...cfg, partants: e.target.value })} /></Field>
            <Field label="Terrain">
              <select style={inp} value={cfg.terr} onChange={e => setCfg({ ...cfg, terr: e.target.value })}>
                {TERRAINS.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
              </select>
            </Field>
            <Field label="Niveau">
              <select style={inp} value={cfg.niveau} onChange={e => setCfg({ ...cfg, niveau: e.target.value })}>
                {NIVEAUX.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
              </select>
            </Field>
          </div>
          <details style={{ marginTop: 12 }}>
            <summary style={{ color: C.muted, fontSize: 13, cursor: "pointer" }}>Paramètres du modèle</summary>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit,minmax(130px,1fr))", gap: 10, marginTop: 10 }}>
              <Field label="Bankroll"><input style={inp} type="number" value={prm.bank} onChange={e => setPrm({ ...prm, bank: e.target.value })} /></Field>
              <Field label="Fraction Kelly">
                <select style={inp} value={prm.kellyFrac} onChange={e => setPrm({ ...prm, kellyFrac: parseFloat(e.target.value) })}>
                  <option value={0.1}>Prudent (10 %)</option><option value={0.25}>Standard (25 %)</option><option value={0.5}>Agressif (50 %)</option>
                </select>
              </Field>
              <Field label="Récence">
                <select style={inp} value={prm.rec} onChange={e => setPrm({ ...prm, rec: e.target.value })}>
                  <option value="std">Standard</option><option value="forme">Forme récente</option><option value="flat">Uniforme</option>
                </select>
              </Field>
              <Field label="Contraste (k)"><input style={inp} type="number" step="0.5" value={prm.k} onChange={e => setPrm({ ...prm, k: e.target.value })} /></Field>
              <Field label="Sens. poids (%/kg)"><input style={inp} type="number" step="0.5" value={prm.sensPoids} onChange={e => setPrm({ ...prm, sensPoids: parseFloat(e.target.value) || 0 })} /></Field>
              <Field label="Âge opt. min"><input style={inp} type="number" value={prm.ageMin} onChange={e => setPrm({ ...prm, ageMin: parseFloat(e.target.value) || 4 })} /></Field>
              <Field label="Âge opt. max"><input style={inp} type="number" value={prm.ageMax} onChange={e => setPrm({ ...prm, ageMax: parseFloat(e.target.value) || 7 })} /></Field>
              <Field label="Lissage historiques"><input style={inp} type="number" step="0.5" value={prm.shrink} onChange={e => setPrm({ ...prm, shrink: e.target.value })} /></Field>
              <Field label="Coef. inédit"><input style={inp} type="number" step="0.05" min="0.3" max="1.3" value={prm.coefInedit} onChange={e => setPrm({ ...prm, coefInedit: e.target.value })} /></Field>
              <Field label="Intensité malus incident"><input style={inp} type="number" step="0.1" min="0" max="2" value={prm.malusInc} onChange={e => setPrm({ ...prm, malusInc: e.target.value })} /></Field>
            </div>
          </details>
        </section>

        {/* Chevaux */}
        <div style={{ color: C.gold, fontSize: 12, textTransform: "uppercase", letterSpacing: 1, marginBottom: 8 }}>
          Partants <span style={{ color: C.muted }}>· {horses.length} saisi{horses.length > 1 ? "s" : ""}</span>
        </div>

        {horses.map((h) => (
          <div key={h.id} style={{ background: C.surface, border: `1px solid ${h.imported ? C.gold : C.line}`, borderRadius: 12, marginBottom: 12, overflow: "hidden" }}>
            {h.imported && (
              <div style={{ background: C.goldDim, color: C.gold, fontSize: 11, padding: "5px 12px", letterSpacing: 0.5 }}>
                Rempli par l'IA depuis votre image — vérifiez les champs avant de calculer
              </div>
            )}
            <div style={{ display: "grid", gridTemplateColumns: "minmax(52px,.6fr) minmax(120px,2fr) repeat(3,minmax(70px,1fr)) auto", gap: 8, padding: "10px 12px", alignItems: "end", background: C.goldDim }}>
              <Field label="N°"><input style={{ ...inp, fontWeight: 700, textAlign: "center" }} type="number" placeholder="—" value={h.num} onChange={e => upd(h.id, "num", e.target.value)} /></Field>
              <Field label="Nom"><input style={{ ...inp, fontWeight: 700, color: C.gold }} value={h.name} onChange={e => upd(h.id, "name", e.target.value)} /></Field>
              <Field label="Âge"><input style={inp} type="number" value={h.age} onChange={e => upd(h.id, "age", e.target.value)} /></Field>
              <Field label="Poids (kg)"><input style={inp} type="number" step="0.5" value={h.poids} onChange={e => upd(h.id, "poids", e.target.value)} /></Field>
              <Field label="Cote"><input style={inp} type="number" step="0.1" placeholder="ex. 6.5" value={h.cote} onChange={e => upd(h.id, "cote", e.target.value)} /></Field>
              <button onClick={() => remove(h.id)} style={btn("transparent", C.muted, { border: `1px solid ${C.line2}`, padding: "8px 12px" })}>×</button>
            </div>
            <div style={{ padding: "8px 12px 12px", overflowX: "auto" }}>
              <table style={{ width: "100%", minWidth: 490, borderCollapse: "collapse", fontSize: 12.5 }}>
                <thead>
                  <tr>
                    {["", "Rang", "Partants", "Incident", "Niveau", "Dist (m)", "Terrain"].map((t, i) => (
                      <th key={i} style={{ color: C.muted, fontWeight: 600, fontSize: 10, textTransform: "uppercase", padding: "5px 3px", borderBottom: `1px solid ${C.line}` }}>{t}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {h.perfs.map((p, i) => (
                    <tr key={i}>
                      <td style={{ color: C.gold, fontWeight: 700, width: 30, textAlign: "center" }}>C{i + 1}</td>
                      <td style={{ padding: 3 }}><input style={{ ...inp, textAlign: "center", padding: "6px 3px" }} type="number" placeholder="—" value={p.rank} onChange={e => updPerf(h.id, i, "rank", e.target.value)} /></td>
                      <td style={{ padding: 3 }}><input style={{ ...inp, textAlign: "center", padding: "6px 3px", borderColor: p.rank !== "" && p.part === "" ? C.red : C.line2 }} type="number" placeholder="—" value={p.part} onChange={e => updPerf(h.id, i, "part", e.target.value)} /></td>
                      <td style={{ padding: 3 }}>
                        <select style={{ ...inp, padding: "6px 3px", color: p.incident ? C.red : C.txt }} value={p.incident} onChange={e => updPerf(h.id, i, "incident", e.target.value)}>
                          {INCIDENT_OPTIONS.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
                        </select>
                      </td>
                      <td style={{ padding: 3 }}>
                        <select style={{ ...inp, padding: "6px 3px" }} value={p.niveau} onChange={e => updPerf(h.id, i, "niveau", e.target.value)}>
                          {NIVEAUX.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
                        </select>
                      </td>
                      <td style={{ padding: 3 }}><input style={{ ...inp, textAlign: "center", padding: "6px 3px" }} type="number" placeholder="—" value={p.dist} onChange={e => updPerf(h.id, i, "dist", e.target.value)} /></td>
                      <td style={{ padding: 3 }}>
                        <select style={{ ...inp, padding: "6px 3px" }} value={p.terr} onChange={e => updPerf(h.id, i, "terr", e.target.value)}>
                          {TERRAINS.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
                        </select>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <label style={{ display: "flex", alignItems: "center", gap: 7, fontSize: 11.5, color: h.inedit ? C.blue : C.muted, marginTop: 8, cursor: "pointer" }}>
                <input type="checkbox" checked={h.inedit} onChange={e => upd(h.id, "inedit", e.target.checked)} />
                <span><b>Cheval inédit</b> — il n'a jamais couru (à cocher seulement si l'absence de performance est un fait, pas un oubli de saisie)</span>
              </label>
              <div style={{ fontSize: 11, color: C.muted, marginTop: 6 }}>
                C1 = plus récente. Ligne vide = ignorée. Champ Partants en rouge = à compléter (souvent absent des fiches).
              </div>
            </div>
          </div>
        ))}

        {err && <div style={{ background: "rgba(229,83,61,.12)", border: `1px solid ${C.red}`, color: C.red, borderRadius: 10, padding: "10px 14px", fontSize: 13, marginBottom: 10 }}>{err}</div>}

        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, margin: "14px 0" }}>
          <button disabled={busyRace || busy} onClick={() => raceRef.current?.click()}
            style={btn(C.gold, "#14100a", { opacity: busyRace || busy ? 0.6 : 1 })}>
            {busyRace ? "Lecture du programme en cours…" : "Importer une course complète (photo/PDF)"}
          </button>
          <button disabled={busy || busyRace} onClick={() => fileRef.current?.click()}
            style={btn(C.surface, C.gold, { border: `1px solid ${C.gold}`, opacity: busy || busyRace ? 0.6 : 1 })}>
            {busy ? "Lecture de la fiche en cours…" : "Importer une fiche cheval (photo/PDF)"}
          </button>
          <button onClick={() => { setHorses(hs => [...hs, newHorse()]); setResults(null); }} style={btn(C.surface, C.txt, { border: `1px solid ${C.line2}` })}>+ Cheval vide</button>
          <button onClick={() => { setHorses([]); setResults(null); }} style={btn(C.surface, C.red, { border: `1px solid ${C.line2}` })}>Tout effacer</button>
          <input ref={fileRef} type="file" accept="image/png,image/jpeg,image/webp,application/pdf" style={{ display: "none" }} onChange={onImportImage} />
          <input ref={raceRef} type="file" accept="image/png,image/jpeg,image/webp,application/pdf" style={{ display: "none" }} onChange={onImportRace} />
        </div>

        <button onClick={calc} style={btn(C.gold, "#14100a", { width: "100%", padding: 14, fontSize: 15, textTransform: "uppercase" })}>
          Calculer le classement &amp; les values
        </button>

        {/* Résultats */}
        {results && (
          <section style={{ background: C.surface, border: `1px solid ${C.line}`, borderRadius: 12, padding: 16, marginTop: 16 }}>
            <div style={{ background: C.goldDim, border: `1px solid ${C.gold}`, borderRadius: 10, padding: "10px 14px", marginBottom: 12, display: "flex", flexWrap: "wrap", gap: "6px 18px", fontSize: 13 }}>
              <b style={{ color: C.gold }}>{cfg.hippo}</b>
              <span>{cfg.dist} m</span>
              <span><b>{results.nbPart} partants</b>{results.nVirt > 0 && <span style={{ color: C.muted }}> (dont {results.nVirt} non analysés)</span>}</span>
              <span style={{ color: C.muted }}>{results.nbPart >= 8 ? "Placé = 3 premiers" : results.nbPart >= 4 ? "Placé = 2 premiers" : "Pas de placé"}</span>
              <span style={{ marginLeft: "auto", color: C.muted }}>
                {results.overround !== null ? <>Overround : <b style={{ color: C.txt }}>{pct(results.overround)}</b></> : "Cotes incomplètes"}
              </span>
            </div>

            <div style={{ color: C.gold, fontSize: 11, textTransform: "uppercase", letterSpacing: 0.8, margin: "4px 0 8px" }}>
              Paris combinés — meilleures combinaisons du modèle
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit,minmax(215px,1fr))", gap: 9, marginBottom: 12 }}>
              <ComboBlock title="Couplé gagnant (2 premiers)" combos={results.couple.desordre} />
              <ComboBlock title="Couplé ordre" combos={results.couple.ordre} />
              <ComboBlock title="Couplé placé (2 parmi 3)" combos={results.couplePlace}
                note={results.nbPart < 8 ? "Proposé à partir de 8 partants" : null} />
              <ComboBlock title="2 sur 4 (2 parmi 4)" combos={results.deuxSur4}
                note={results.nbPart < 14 ? "Proposé sur les courses Quinté+ (14 partants et plus)" : null} />
              <ComboBlock title="Trio (3 premiers, désordre)" combos={results.tierce.desordre} />
              <ComboBlock title="Tiercé ordre" combos={results.tierce.ordre} />
              <ComboBlock title="Quarté désordre" combos={results.quarte.desordre} />
              <ComboBlock title="Quarté ordre" combos={results.quarte.ordre} />
              <ComboBlock title="Quinté désordre" combos={results.quinte.desordre} />
              <ComboBlock title="Quinté ordre" combos={results.quinte.ordre} />
            </div>
            <div style={{ fontSize: 11, color: C.muted, marginBottom: 14, fontStyle: "italic" }}>
              Numéros de dossard, classés par probabilité décroissante. Paris à ordre et désordre : calcul exact.
              Couplé placé et 2 sur 4 : estimés par simulation de 20 000 courses (± 0,3 %).
              Une probabilité faible n'est pas un mauvais pari — comparez-la au rapport attendu, pas à zéro.
            </div>

            <div style={{ overflowX: "auto" }}>
              <table style={{ width: "100%", minWidth: 760, borderCollapse: "collapse", fontSize: 13 }}>
                <thead>
                  <tr>
                    {["#", "Cheval", "Score", "Régularité", "Modèle vs marché", "1er · T2 · T3 · T4", "Cote", "Value", "Mise", "Reco"].map((t, i) => (
                      <th key={i} style={{ background: C.surface2, color: C.gold, padding: "8px 7px", textAlign: "left", fontSize: 10.5, textTransform: "uppercase", letterSpacing: 0.6, borderBottom: `2px solid ${C.gold}` }}>{t}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {results.rows.map((r, i) => {
                    const maxP = Math.max(...results.rows.map(x => Math.max(x.prob, x.pImp || 0)));
                    const [regT, regC] = regTxt(r);
                    return (
                      <tr key={i} style={{ background: i === 0 ? "rgba(232,179,60,.08)" : "transparent" }}>
                        <td style={{ padding: "8px 7px", borderBottom: `1px solid ${C.line}`, fontWeight: 700 }}>{i + 1}</td>
                        <td style={{ padding: "8px 7px", borderBottom: `1px solid ${C.line}` }}>
                          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                            {r.num != null && (
                              <span style={{ background: C.gold, color: "#14100a", fontWeight: 800, borderRadius: 7, minWidth: 26, textAlign: "center", padding: "3px 5px", fontSize: 13 }}>{r.num}</span>
                            )}
                            <div>
                              <div style={{ fontWeight: 700 }}>{r.name}</div>
                              <div style={{ fontSize: 11, color: C.muted }}>
                                {r.age} ans · {r.poids || "—"} kg · {r.nPerfs} perfs
                                {r.nChutes >= 2 && r.tauxChute >= 0.34
                                  ? <span style={{ color: C.red, fontWeight: 700 }}> · Sauteur fragile ({r.nChutes} chutes/{r.nPerfs})</span>
                                  : r.nChutes >= 1
                                  ? <span style={{ color: C.gold }}> · {r.nChutes} chute{r.nChutes > 1 ? "s" : ""}</span>
                                  : null}
                              </div>
                            </div>
                          </div>
                        </td>
                        <td style={{ padding: "8px 7px", borderBottom: `1px solid ${C.line}`, fontWeight: 700 }}>{r.score.toFixed(3)}</td>
                        <td style={{ padding: "8px 7px", borderBottom: `1px solid ${C.line}`, color: regC, fontSize: 12 }}>{regT}</td>
                        <td style={{ padding: "8px 7px", borderBottom: `1px solid ${C.line}`, minWidth: 130 }}>
                          <div style={{ height: 6, background: C.surface2, borderRadius: 3, marginBottom: 3 }}>
                            <div style={{ height: 6, width: `${maxP > 0 ? (100 * r.prob) / maxP : 0}%`, background: C.gold, borderRadius: 3 }} />
                          </div>
                          <div style={{ height: 6, background: C.surface2, borderRadius: 3 }}>
                            <div style={{ height: 6, width: `${r.pImp && maxP > 0 ? (100 * r.pImp) / maxP : 0}%`, background: C.blue, borderRadius: 3 }} />
                          </div>
                          <div style={{ display: "flex", justifyContent: "space-between", fontSize: 10, color: C.muted, marginTop: 2 }}>
                            <span>Modèle {pct(r.prob)}</span>{r.pImp && <span>Marché {pct(r.pImp)}</span>}
                          </div>
                        </td>
                        <td style={{ padding: "8px 7px", borderBottom: `1px solid ${C.line}`, whiteSpace: "nowrap", fontSize: 12 }}>
                          <b style={{ color: C.gold }}>{pct(r.pTop1)}</b> · {pct(r.pTop2)} · {pct(r.pTop3)} · {pct(r.pTop4)}
                        </td>
                        <td style={{ padding: "8px 7px", borderBottom: `1px solid ${C.line}` }}>{r.cote ? r.cote.toFixed(1) : "—"}</td>
                        <td style={{ padding: "8px 7px", borderBottom: `1px solid ${C.line}`, fontWeight: 700, color: r.value === null ? C.muted : r.value > 0 ? C.green : C.red }}>
                          {r.value === null ? "—" : (r.value > 0 ? "+" : "") + pct(r.value)}
                        </td>
                        <td style={{ padding: "8px 7px", borderBottom: `1px solid ${C.line}`, color: C.green, fontWeight: 700 }}>
                          {r.stake > 0.01 ? r.stake.toFixed(1) + " u" : "—"}
                        </td>
                        <td style={{ padding: "8px 7px", borderBottom: `1px solid ${C.line}`, fontSize: 12 }}>{reco(r, i)}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            <div style={{ marginTop: 12, fontSize: 12, color: C.muted, lineHeight: 1.6, borderLeft: `3px solid ${C.gold}`, paddingLeft: 12 }}>
              Barre <b style={{ color: C.gold }}>or</b> = probabilité du modèle, barre <b style={{ color: C.blue }}>bleue</b> = probabilité implicite de la cote.
              Value = p × cote − 1. Mise = Kelly fractionné ({Math.round(prm.kellyFrac * 100)} %) sur {prm.bank} unités.
              Petits historiques lissés vers la moyenne du lot. Partants non analysés traités en outsiders moyens.
            </div>
            <div style={{ marginTop: 10, fontSize: 11.5, color: C.muted, textAlign: "center", fontStyle: "italic" }}>
              Outil d'aide à la décision — aucun modèle ne garantit un gain. Jouez uniquement ce que vous pouvez vous permettre de perdre.
            </div>
          </section>
        )}
      </div>
    </div>
  );
}
