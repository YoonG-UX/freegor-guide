# Format des guides

Un guide est un texte enregistré avec `Freegor:RegisterGuide([[ ... ]])`.
Une commande par ligne, l'indentation est libre. Les lignes vides et celles qui commencent par `--` ou `#` sont ignorées.

## En-tête (avant le premier `step`)

| Ligne | Rôle |
| --- | --- |
| `guide <titre>` | **Obligatoire.** Titre unique du guide. |
| `faction Alliance` / `Horde` / `Neutral` | Le sélecteur n'affiche que les guides de la faction du joueur. |
| `levels 1-6` | Tranche de niveaux (sert au tri dans le sélecteur). |
| `next <titre>` | Guide proposé à la fin de celui-ci. |
| `zone 1429, Elwynn Forest, Forêt d'Elwynn` | Zone par défaut des `goto` : un uiMapID ou des noms ; le premier qui existe dans le client est utilisé. |
| `race Dwarf, Gnome` | Le sélecteur ne montre le guide qu'à ces races (guides de départ). |
| `category <nom>` | Rubrique du menu : `leveling` (par défaut), `mounts`, `gold`, `reputation`, `achievements`. |
| `loop` | Circuit : arrivé au bout, le guide recommence à la première étape. |
| `author`, `description` | Informatifs (la description s'affiche dans le menu). |

## Étapes

`step` commence une nouvelle étape. Une étape contient des objectifs :

| Objectif | Validé quand… |
| --- | --- |
| `accept <questID> [titre]` | la quête est dans le journal (ou déjà rendue) |
| `turnin <questID> [titre]` | la quête est rendue |
| `do <questID> [titre]` | tous les objectifs de la quête sont remplis |
| `kill <texte> \|q <questID>/<n>` | l'objectif n° n de la quête est rempli (sans `/n` : toute la quête) |
| `collect <texte> \|q <questID>/<n>` | idem |
| `level <n>` | le joueur atteint le niveau n |
| `goto [zone] x,y [\|r rayon]` | voir ci-dessous |
| `talk <PNJ> \|n <npcID>` | le joueur ouvre un dialogue avec ce PNJ (sans `\|n` : information seulement) |
| `home <lieu>` | la pierre de foyer est liée ici (événement du jeu, ou lieu de rappel actuel) |
| `fpath <lieu>` | le point de vol est découvert (carte des vols ouverte pendant l'étape, ou déjà connu) |
| `fly <destination>` | le joueur prend un vol |
| `hearth [lieu]` | le joueur utilise sa pierre de foyer |
| `train` | le joueur ouvre la fenêtre d'un maître de classe |
| `gold <montant>` | le joueur a au moins ce nombre de pièces d'or |
| `item <itemID> [nombre] [nom]` | l'objet est dans les sacs (en quantité suffisante) |
| `rep <factionID> <niveau> [nom]` | réputation atteinte : `neutral`, `friendly`, `honored`, `revered`, `exalted` |
| `achieve <id> [nom]` | haut fait obtenu (information seulement sur un client sans hauts faits) |
| `use <objet>`, `buy <objet>` | information seulement |
| `note <texte>` | information seulement |

Le titre de quête est facultatif : le client affiche son propre nom (traduit) dès que la quête est dans le journal.

Toute ligne accepte `|fr <texte>` : le texte affiché sur un client français
(titre de quête, nom de PNJ, de monstre ou d'objet, note).

### Avancement

- Une étape est terminée quand tous ses objectifs vérifiables (quêtes, niveau, actions) le sont ;
  le guide passe alors à la prochaine étape non terminée.
- Sinon, une étape avec des `talk ... |n <id>` se valide quand le joueur a parlé à ces PNJ.
- `goto` place la flèche. Si c'est le seul objectif vérifiable de l'étape, l'étape se valide
  à l'arrivée (12 mètres par défaut, ou `|r <rayon>`).
- Un `fpath` ne se valide qu'au bon point de vol : celui dont le nom correspond, ou celui du
  maître de vol nommé dans l'étape.
- Une étape sans rien de vérifiable (que des `note` / `talk`) attend un clic sur « Suivant ».
- `kill` / `collect` sans `|q` sont de simples indications.

### Conditions

`only <liste>` restreint l'étape à certaines classes, races ou factions (jetons du client,
insensibles à la casse et aux espaces) :

```
step
  only Warrior
  accept 3100 Simple Letter
step
  only !Human
  note Cette étape ne concerne pas les humains.
```

Classes : `WARRIOR, PALADIN, HUNTER, ROGUE, PRIEST, SHAMAN, MAGE, WARLOCK, DRUID`…
Races : `Human, Dwarf, NightElf, Gnome, Orc, Scourge, Tauren, Troll`…

## Guides générés

Les guides de `FreegorGuide/Guides/` sont générés à partir des parcours de `tools/routes/`
(voir `tools/README.md`). Pour corriger un guide, modifiez son parcours puis régénérez-le.
