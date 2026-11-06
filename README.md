# Freegor Guide

Guide de leveling pas à pas pour World of Warcraft (client WoW Forever), **gratuit et communautaire**.
Fenêtre d'étapes, validation automatique des objectifs, flèche de navigation, compatible TomTom.

## Guides inclus : Alliance 1-30

| Niveaux | Humain | Nain / Gnome | Elfe de la nuit |
| --- | --- | --- | --- |
| 1-6 | Comté-du-Nord | Vallée de Froide-Combe | Sombrevallon |
| 6-11 | Forêt d'Elwynn | Dun Morogh | Teldrassil |
| 11-16 | Marche de l'Ouest | Loch Modan | Sombrivage (11-17) |
| 16-21 | Les Carmines | | |
| 21-25 | Bois de la Pénombre | | |
| 25-28 | Les Paluns | | |
| 28-30 | Bois de la Pénombre et Les Carmines | | |

À la première connexion, le guide adapté à votre race et à votre niveau est chargé tout seul.
Chaque guide propose le suivant à la fin.

## Installation

1. Téléchargez ce dépôt (bouton *Code → Download ZIP*).
2. Copiez le dossier `FreegorGuide` dans `World of Warcraft/_<version>_/Interface/AddOns/`.
3. Relancez le jeu et activez **Freegor Guide** dans la liste des addons.

## Utilisation

| Commande | Effet |
| --- | --- |
| `/freegor` ou `/fg` | Afficher / masquer la fenêtre |
| `/freegor list` | Choisir un guide |
| `/freegor next`, `/freegor prev` | Étape suivante / précédente |
| `/freegor step 12` | Aller à l'étape 12 |
| `/freegor arrow` | Afficher / masquer la flèche |
| `/freegor auto` | Activer / désactiver l'acceptation et le rendu automatiques des quêtes du guide |
| `/freegor reset` | Remettre les fenêtres à leur place |

- Les étapes avancent toutes seules quand le jeu détecte l'action demandée :
  quête acceptée, objectif rempli, quête rendue, niveau atteint, arrivée à destination,
  dialogue avec le bon PNJ, pierre de foyer liée, point de vol découvert, vol pris,
  pierre de foyer utilisée, visite au maître de classe.
- Les quêtes déjà terminées sont reconnues : en chargeant un guide, vous reprenez directement
  à la première quête qu'il vous reste à faire.
- Avec `/freegor auto`, les quêtes du guide sont acceptées et rendues automatiquement
  (maintenez Maj pour suspendre ; les quêtes avec un choix de récompense restent manuelles).
- Cliquez sur une ligne « Aller en… » pour y placer la flèche.
- La fenêtre et la flèche se déplacent à la souris ; leur position est sauvegardée.
- La progression est sauvegardée par personnage.

## Écrire un guide

Les guides sont du texte simple. Exemple :

```
guide Northshire Valley (1-6)
faction Alliance
levels 1-6
zone 1429, Elwynn Forest, Forêt d'Elwynn

step
  goto 48.2,42.0
  talk Deputy Willem
  accept 783 A Threat Within
step
  kill 10 Kobold Vermin |q 7/1
```

Le format complet est décrit dans [docs/FORMAT.md](docs/FORMAT.md).

Les guides fournis sont **générés** à partir de parcours courts (`tools/routes/*.route`) :
on y écrit l'ordre des quêtes, et le générateur ajoute les PNJ, les coordonnées et les noms
français, puis vérifie les enchaînements de quêtes. Voir [tools/README.md](tools/README.md).
Un autre addon peut aussi fournir ses propres guides (pack de guides) avec `## Dependencies: FreegorGuide`
et des appels à `Freegor:RegisterGuide([[ ... ]])`.

## Contribuer

- Les IDs de quêtes, PNJ et coordonnées viennent des données publiques de WoW Forever
  (base de données QuestieDB). Signalez toute étape fausse en jeu avec le nom du guide et le numéro d'étape.
- Lancez les tests avant de proposer une modification :

```bash
lua5.1 tests/run.lua
```

Les tests chargent l'addon avec une API WoW simulée : ils vérifient la syntaxe, le chargement du `.toc`,
l'analyse des guides et l'avancement automatique des étapes. Ils ne remplacent pas un essai en jeu.

## Signaler un bug

Activez les erreurs Lua (`/console scriptErrors 1`) ou installez BugSack, puis ouvrez une *issue*
avec le message d'erreur complet, la version du client et l'étape du guide concernée.
