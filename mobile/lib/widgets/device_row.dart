import 'package:flutter/material.dart';

import '../data/remote/compte_api.dart';
import 'auth_styles.dart';

const _jours = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

String _deux(int n) => n.toString().padLeft(2, '0');

/// « 21 h 41 » (heure locale).
String formaterHeure(DateTime d) {
  final l = d.toLocal();
  return '${l.hour} h ${_deux(l.minute)}';
}

/// « 17/11/2026 » (date locale).
String formaterDate(DateTime d) {
  final l = d.toLocal();
  return '${_deux(l.day)}/${_deux(l.month)}/${l.year}';
}

/// « 14/11 », ou « 14/11/2025 » si l'année diffère de celle de [maintenant].
String formaterJourMois(DateTime d, DateTime maintenant) {
  final l = d.toLocal();
  final base = '${_deux(l.day)}/${_deux(l.month)}';
  return l.year == maintenant.toLocal().year ? base : '$base/${l.year}';
}

/// « samedi 14/11 à 21 h 41 » (année ajoutée si elle diffère).
String formaterJourHeure(DateTime d, DateTime maintenant) {
  final l = d.toLocal();
  return '${_jours[l.weekday - 1]} ${formaterJourMois(l, maintenant)} à ${formaterHeure(l)}';
}

/// « actif maintenant », « actif il y a 5 min », « dernière activité hier
/// à 23 h 12 », « dernière activité le 14/11 à 21 h 41 » (heure locale ;
/// année ajoutée si elle diffère).
String formaterActivite(Appareil a, DateTime maintenant) {
  final activite = a.derniereActivite.toLocal();
  final m = maintenant.toLocal();
  final ecart = m.difference(activite);
  if (a.estCourant || ecart < const Duration(minutes: 1)) return 'actif maintenant';
  if (ecart < const Duration(hours: 1)) return 'actif il y a ${ecart.inMinutes} min';
  final jour = DateTime(m.year, m.month, m.day);
  final jourActivite = DateTime(activite.year, activite.month, activite.day);
  final heure = formaterHeure(activite);
  if (jourActivite == jour) return "dernière activité aujourd'hui à $heure";
  if (jourActivite == DateTime(jour.year, jour.month, jour.day - 1)) return 'dernière activité hier à $heure';
  return 'dernière activité le ${formaterJourMois(activite, m)} à $heure';
}

String libelleType(TypeAppareil t) => switch (t) {
  TypeAppareil.telephone => 'Application Android',
  TypeAppareil.navigateur => 'Navigateur · web app',
};

/// `device-row` : icône + nom (« Cet appareil », « Nouveau »), type et
/// dernière activité, action `cta-ghost` « Retirer » (48dp) facultative.
/// TalkBack : un nœud groupé pour l'appareil, un bouton pour le retrait.
class LigneAppareil extends StatelessWidget {
  final Appareil appareil;
  final DateTime maintenant;
  final VoidCallback? onRetirer;

  /// Marques « Cet appareil » / « Nouveau » (absentes sur Appareil bloqué).
  final bool marques;

  const LigneAppareil({
    super.key,
    required this.appareil,
    required this.maintenant,
    this.onRetirer,
    this.marques = true,
  });

  @override
  Widget build(BuildContext context) {
    final a = appareil;
    final detail = '${libelleType(a.type)} · ${formaterActivite(a, maintenant)}';
    final lu = [
      a.nom,
      if (marques && a.estCourant) 'cet appareil',
      if (marques && a.nouveau) 'nouveau',
      detail,
    ].join(', ');
    const marque = TextStyle(fontSize: 11, letterSpacing: .6);
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: JetonsAuth.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label: lu,
              excludeSemantics: true,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: JetonsAuth.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: JetonsAuth.lineCard),
                    ),
                    child: Icon(
                      a.type == TypeAppareil.telephone ? Icons.smartphone : Icons.laptop,
                      size: 20,
                      color: JetonsAuth.text,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: a.nom),
                              if (marques && a.estCourant)
                                TextSpan(
                                  text: '  ${'Cet appareil'.toUpperCase()}',
                                  style: marque.copyWith(fontWeight: FontWeight.w700, color: JetonsAuth.text),
                                ),
                              if (marques && a.nouveau)
                                TextSpan(
                                  text: '  ${'Nouveau'.toUpperCase()}',
                                  style: marque.copyWith(fontWeight: FontWeight.w600, color: JetonsAuth.muted),
                                ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: JetonsAuth.text),
                        ),
                        const SizedBox(height: 2),
                        Text(detail, style: const TextStyle(fontSize: 11.5, height: 1.4, color: JetonsAuth.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onRetirer != null) ...[
            const SizedBox(width: 8),
            Semantics(
              label: 'Retirer ${a.nom}',
              button: true,
              excludeSemantics: true,
              onTap: onRetirer,
              child: CtaFantome(texte: 'Retirer', onPressed: onRetirer),
            ),
          ],
        ],
      ),
    );
  }
}

/// Confirmation légère (Annuler / [action]). Vrai si confirmé.
Future<bool> confirmer(
  BuildContext context, {
  required String titre,
  required String texte,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: JetonsAuth.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: JetonsAuth.lineCard),
      ),
      title: Text(
        titre,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: JetonsAuth.text),
      ),
      content: Text(texte, style: JetonsAuth.sub),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: JetonsAuth.text, minimumSize: const Size(48, 48)),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: JetonsAuth.text,
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}
