import 'package:jelvo/features/signalements/models/blocage.dart';
import 'package:jelvo/features/signalements/models/signalement.dart';
import 'package:jelvo/features/signalements/repository/signalement_repository.dart';

/// Faux dépôt de signalements.
///
/// **Surchargé par tous les fichiers de test**, comme les onze autres : un
/// provider oublié tombe sur `Supabase.instance`, absent en test, et
/// l'`AsyncNotifier` qui échoue à la construction rend un `AsyncValue` en
/// erreur dont le `.value` nul retombe sur la liste vide de repli. L'écran
/// s'affiche, vide, et le test passe pour de mauvaises raisons.
class FakeSignalementRepository implements SignalementRepository {
  FakeSignalementRepository({
    this.moderateur = false,
    List<Signalement>? signalements,
    this.issueSignalement = SignalementOutcome.signale,
    this.issueTraitement = SignalementOutcome.traite,
    this.issueSuppression = SignalementOutcome.supprime,
    this.leveEnLecture = false,
    List<PersonneBloquee>? bloques,
    this.issueBlocage = BlocageOutcome.bloque,
    this.issueDeblocage = BlocageOutcome.debloque,
  }) : _signalements = List<Signalement>.of(signalements ?? const []),
       _bloques = List<PersonneBloquee>.of(bloques ?? const []);

  /// Ce que `est_moderateur()` répond.
  bool moderateur;

  final List<Signalement> _signalements;

  /// Mots d'état à rendre, pour éprouver chaque branche sans base.
  SignalementOutcome issueSignalement;
  SignalementOutcome issueTraitement;
  SignalementOutcome issueSuppression;

  /// Pour éprouver l'état d'erreur de l'écran.
  bool leveEnLecture;

  // ---- Ce qui a été reçu, pour les assertions ----------------------------
  SignalementCible? derniereCible;
  String? dernierCibleId;
  SignalementMotif? dernierMotif;
  String? dernierCommentaire;
  int envois = 0;

  String? dernierTraite;
  String? derniereNote;
  bool? dernierDrapeauTraite;
  int traitements = 0;

  String? dernierMessageSupprime;
  int suppressions = 0;

  final List<PersonneBloquee> _bloques;

  BlocageOutcome issueBlocage;
  BlocageOutcome issueDeblocage;

  String? dernierBloque;
  String? dernierDebloque;
  int blocages = 0;
  int deblocages = 0;
  int lecturesBloques = 0;

  /// Nombre de relectures, par onglet. Traiter doit relire **les deux** : la
  /// ligne passe de l'un à l'autre.
  int lecturesFile = 0;
  int lecturesArchive = 0;

  @override
  Future<SignalementOutcome> signaler({
    required SignalementCible cible,
    required String cibleId,
    required SignalementMotif motif,
    String? commentaire,
  }) async {
    envois++;
    derniereCible = cible;
    dernierCibleId = cibleId;
    dernierMotif = motif;
    dernierCommentaire = commentaire;
    return issueSignalement;
  }

  @override
  Future<bool> estModerateur() async => moderateur;

  @override
  Future<List<Signalement>> fetchSignalements({bool traites = false}) async {
    if (traites) {
      lecturesArchive++;
    } else {
      lecturesFile++;
    }
    if (leveEnLecture) throw Exception('lecture impossible');
    return _signalements
        .where((Signalement s) => s.estTraite == traites)
        .toList();
  }

  @override
  Future<SignalementOutcome> traiter({
    required String id,
    String? note,
    bool traite = true,
  }) async {
    traitements++;
    dernierTraite = id;
    derniereNote = note;
    dernierDrapeauTraite = traite;

    // Le faux dépôt déplace vraiment la ligne : sans cela, l'assertion « un
    // signalement traité ne revient plus » passerait parce que rien n'a été
    // relu, et non parce que la règle tient.
    final int i = _signalements.indexWhere((Signalement s) => s.id == id);
    if (i >= 0 && issueTraitement.isSuccess) {
      final Signalement avant = _signalements[i];
      _signalements[i] = Signalement(
        id: avant.id,
        cible: avant.cible,
        motif: avant.motif,
        creeLe: avant.creeLe,
        commentaire: avant.commentaire,
        contexte: avant.contexte,
        traiteLe: traite ? DateTime(2026, 11, 22, 9) : null,
        note: note ?? avant.note,
        messageId: avant.messageId,
        groupId: avant.groupId,
        profilId: avant.profilId,
        auteurNom: avant.auteurNom,
        auteurAvatar: avant.auteurAvatar,
        viseNom: avant.viseNom,
        viseAvatar: avant.viseAvatar,
        groupeNom: avant.groupeNom,
        messageEfface: avant.messageEfface,
      );
    }
    return issueTraitement;
  }

  @override
  Future<SignalementOutcome> supprimerMessage(String signalementId) async {
    suppressions++;
    dernierMessageSupprime = signalementId;

    final int i = _signalements.indexWhere(
      (Signalement s) => s.id == signalementId,
    );
    if (i >= 0 && issueSuppression == SignalementOutcome.supprime) {
      final Signalement avant = _signalements[i];
      _signalements[i] = Signalement(
        id: avant.id,
        cible: avant.cible,
        motif: avant.motif,
        creeLe: avant.creeLe,
        commentaire: avant.commentaire,
        contexte: avant.contexte,
        traiteLe: avant.traiteLe,
        note: avant.note,
        messageId: avant.messageId,
        groupId: avant.groupId,
        profilId: avant.profilId,
        auteurNom: avant.auteurNom,
        auteurAvatar: avant.auteurAvatar,
        viseNom: avant.viseNom,
        viseAvatar: avant.viseAvatar,
        groupeNom: avant.groupeNom,
        messageEfface: true,
      );
    }
    return issueSuppression;
  }

  @override
  Future<BlocageOutcome> bloquer(String userId) async {
    blocages++;
    dernierBloque = userId;
    // Le faux dépôt **ajoute vraiment** la personne : sans cela, l'assertion
    // « l'écran offre désormais de débloquer » passerait parce que rien n'a
    // été relu, et non parce que la relecture a eu lieu.
    if (issueBlocage.isSuccess &&
        !_bloques.any((PersonneBloquee p) => p.userId == userId)) {
      _bloques.add(
        PersonneBloquee(
          userId: userId,
          creeLe: DateTime(2026, 11, 22, 9),
          pseudo: 'lea.marchand',
          nom: 'Léa Marchand',
        ),
      );
    }
    return issueBlocage;
  }

  @override
  Future<BlocageOutcome> debloquer(String userId) async {
    deblocages++;
    dernierDebloque = userId;
    if (issueDeblocage.isSuccess) {
      _bloques.removeWhere((PersonneBloquee p) => p.userId == userId);
    }
    return issueDeblocage;
  }

  @override
  Future<List<PersonneBloquee>> fetchBloques() async {
    lecturesBloques++;
    if (leveEnLecture) throw Exception('lecture impossible');
    return List<PersonneBloquee>.of(_bloques);
  }
}
