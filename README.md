# Freegor Guide

Guide de leveling pas à pas pour World of Warcraft, **gratuit et communautaire**.
Fenêtre d'étapes, validation automatique des objectifs, flèche de navigation, compatible TomTom.

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
| `/freegor reset` | Remettre les fenêtres à leur place |

- Les étapes avancent toutes seules quand vous acceptez, terminez ou rendez une quête,
  atteignez un niveau ou arrivez à destination.
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
Pour ajouter un guide, créez un fichier dans `FreegorGuide/Guides/` et ajoutez-le à la fin de `FreegorGuide.toc`.
Un autre addon peut aussi fournir ses propres guides (pack de guides) avec `## Dependencies: FreegorGuide`
et des appels à `Freegor:RegisterGuide([[ ... ]])`.

## Contribuer

- Les IDs de quêtes et les coordonnées doivent être vérifiés en jeu sur le serveur ciblé.
- Lancez les tests avant de proposer une modification :

```bash
lua5.1 tests/run.lua
```

Les tests chargent l'addon avec une API WoW simulée : ils vérifient la syntaxe, le chargement du `.toc`,
l'analyse des guides et l'avancement automatique des étapes. Ils ne remplacent pas un essai en jeu.

## Signaler un bug

Activez les erreurs Lua (`/console scriptErrors 1`) ou installez BugSack, puis ouvrez une *issue*
avec le message d'erreur complet, la version du client et l'étape du guide concernée.
