# Budget Voyage

Application mobile (Flutter, Android et iPhone) pour planifier un séjour en partant de son budget.
Elle est optimisée pour les grandes tablettes comme la Samsung Galaxy Tab S11 Ultra : en paysage,
le plan et la carte s'affichent côte à côte.

L'application ne vend rien. Elle affiche les horaires et les prix, puis renvoie vers les sites
officiels pour réserver (Google Flights, Booking.com, Trainline, Google Maps).

## Installer l'APK sur la tablette

À chaque push, GitHub Actions construit l'APK (workflow `.github/workflows/android-apk.yml`) :

1. Onglet **Releases** du dépôt → release **« Budget Voyage — dernier APK »** (`apk-latest`)
   → télécharger `budget-voyage.apk` depuis la tablette.
   L'APK est aussi disponible dans l'artefact `budget-voyage-apk` de chaque exécution, onglet **Actions**.
2. Ouvrir le fichier, puis autoriser l'installation d'applications depuis cette source
   (Paramètres → Applications → Accès spécial → Installer des applis inconnues).

Pour construire l'APK localement (SDK Flutter et Android requis) :

```bash
flutter pub get
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

## Fonctionnalités

- **Bandeau budget** sur chaque étape : budget initial, dépensé, restant et barre de progression.
  Une alerte s'affiche sous 10 % de budget restant.
  Les options trop chères sont grisées (« Hors budget »).
  Le montant dépensé est recalculé à partir des choix en cours : changer un choix remet donc
  l'ancien prix avant de déduire le nouveau.
- **Accueil** : « Nouveau voyage » et « Mes voyages ». Si un voyage est en cours, un raccourci
  vers la saisie des dépenses est affiché.
- **Parcours en 10 étapes** :
  1. Budget, villes de départ et de destination, dates, voyageurs.
  2. Vols aller-retour : horaires, durée, escales, prix ; tri et filtre « vols directs ».
  3. Trajets aéroport → ville calculés depuis l'heure d'arrivée (train, bus, taxi), avec les
     étapes intermédiaires horodatées et un lien Google Maps. Trajet retour vers l'aéroport en option.
  4. Logement : un seul hôtel ou plusieurs villes (liste des villes et nuits par ville).
     Les étapes 5 et 6 se répètent alors pour chaque ville.
  5. Préférences hôtel : le moins cher ou le plus confortable, et une gamme de prix par nuit.
  6. Hôtels : prix, étoiles et avis, triables par prix ou par avis.
     Le montant déduit est prix par nuit × nuits. Lien « Voir l'offre ».
  7. Repas : petit mangeur, gros mangeur ou gourmet. Le montant journalier dépend du coût de la vie
     dans le pays. Si un profil dépasse le budget, l'app le signale et propose le profil inférieur.
  8. Activités par envie et par ville, gratuites en premier, chacune placée à un jour et une heure.
  9. Transports sur place (pass, voiture, taxi), calculés selon la durée du séjour et les activités.
     Les trajets déjà prévus (aéroport, trains entre villes) y sont rappelés.
  10. Récapitulatif par catégorie, puis « Enregistrer ».
- **Plan + carte** :
  - frise jour par jour ;
  - carte OpenStreetMap avec des points numérotés reliés par des flèches, une couleur par jour ;
  - filtre par jour ;
  - toucher une étape du plan centre la carte sur elle, et toucher un point fait défiler le plan.
- **Suivi des dépenses** pendant le voyage :
  - saisie rapide (catégorie + pavé numérique + montants préréglés) ;
  - conversion automatique de devise (taux BCE via frankfurter.app, avec des taux de secours hors ligne) ;
  - budget par jour = budget restant ÷ jours restants, et montant disponible aujourd'hui ;
  - comparaison prévu / réel par catégorie ;
  - notifications à 80 % et 100 % d'une catégorie, et quand le budget total passe sous 10 %.

## Données

Par défaut, l'application utilise des **données simulées réalistes** : leurs prix suivent la
distance et le coût de la vie de la destination, et une mention « données simulées » s'affiche à
l'écran. Elle fonctionne donc sans clé d'API.

Pour avoir de vrais vols et hôtels, il faut déployer le petit serveur `server/index.mjs`. Ce
serveur appelle SerpApi (Google Flights / Google Hotels, 250 recherches gratuites par mois), ce qui
garde la clé hors de l'application :

```bash
SERPAPI_KEY=xxxx node server/index.mjs
flutter build apk --release --dart-define=API_BASE_URL=https://votre-serveur
```

Dans GitHub Actions, on peut définir la variable de dépôt `API_BASE_URL`, ou la saisir au lancement
manuel du workflow. Si le serveur ne répond pas, l'application revient automatiquement aux données
simulées.

Les voyages sont sauvegardés **localement** sur l'appareil (version 1).

## Structure

```
lib/
  models/models.dart          Modèles (voyage, vol, hôtel, activité, dépense…)
  services/                   Données de voyage, villes, devises, plan, suivi, notifications
  state/                      AppState (voyages enregistrés) et PlannerController (brouillon)
  ui/screens/planner/         Les 10 étapes du parcours
  ui/screens/                 Accueil, plan + carte, suivi des dépenses, saisie rapide
server/index.mjs              Serveur optionnel SerpApi
test/                         Tests de la logique budget et du parcours complet
```

Lancer les tests : `flutter test`.
