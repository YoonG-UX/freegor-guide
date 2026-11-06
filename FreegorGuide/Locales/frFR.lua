local _, ns = ...
if GetLocale() ~= "frFR" then return end

local L = ns.L

L.NO_GUIDE        = "Aucun guide chargé. Cliquez sur le livre pour en choisir un."
L.STEP_FMT        = "Étape %d / %d"
L.GUIDE_DONE      = "Guide terminé !"
L.NEXT_GUIDE      = "Guide suivant : %s"
L.LOAD_NEXT       = "Charger le guide suivant"
L.CHOOSE_GUIDE    = "Choisir un guide"
L.PREV            = "Étape précédente"
L.NEXT            = "Étape suivante"
L.SKIP_HINT       = "Cliquez sur un objectif pour placer le repère. Les flèches changent d'étape."
L.MANUAL_HINT     = "Cliquez sur « Suivant » une fois terminé."
L.ARRIVED         = "Vous êtes arrivé."
L.YARDS_FMT       = "%d m"
L.OTHER_ZONE      = "La destination est dans une autre zone : %s"
L.LOADED_FMT      = "Guide chargé : %s"
L.UNKNOWN_GUIDE   = "Guide inconnu : %s"
L.PARSE_ERROR_FMT = "Erreur dans le guide « %s », ligne %d : %s"
L.FILTER_ALL      = "Tous"
L.LEVELS_FMT      = "niveaux %d-%d"

L.GOAL_ACCEPT  = "Accepter |cffffd100%s|r"
L.GOAL_TURNIN  = "Rendre |cffffd100%s|r"
L.GOAL_KILL    = "Tuer %s"
L.GOAL_COLLECT = "Récupérer %s"
L.GOAL_DO      = "Terminer |cffffd100%s|r"
L.GOAL_TALK    = "Parler à |cff00ff96%s|r"
L.GOAL_GOTO    = "Aller en %s"
L.GOAL_LEVEL   = "Atteindre le niveau %d"
L.GOAL_HOME      = "Lier votre pierre de foyer à |cff00ff96%s|r"
L.GOAL_FPATH     = "Découvrir le point de vol de |cff00ff96%s|r"
L.GOAL_FLY       = "Prendre le vol pour |cff00ff96%s|r"
L.GOAL_HEARTH    = "Utiliser votre pierre de foyer"
L.GOAL_HEARTH_TO = "Pierre de foyer vers |cff00ff96%s|r"
L.GOAL_TRAIN     = "Voir votre maître de classe"
L.GOAL_USE       = "Utiliser %s"
L.GOAL_BUY       = "Acheter %s"
L.AUTO_ON        = "Acceptation/rendu automatique des quêtes : |cff00ff00activé|r (Maj pour suspendre)"
L.AUTO_OFF       = "Acceptation/rendu automatique des quêtes : |cffff4040désactivé|r"
L.GOAL_GOLD    = "Avoir |cffffd100%d pièces d'or|r"
L.GOAL_ITEM    = "Obtenir |cffffd100%s|r"
L.GOAL_ITEM_N  = "Obtenir %d x |cffffd100%s|r"
L.GOAL_REP     = "Atteindre %s auprès de |cff00ff96%s|r"
L.GOAL_ACHIEVE = "Haut fait : |cffffd100%s|r"
L.STANDING_1, L.STANDING_2, L.STANDING_3, L.STANDING_4 = "Détesté", "Hostile", "Inamical", "Neutre"
L.STANDING_5, L.STANDING_6, L.STANDING_7, L.STANDING_8 = "Amical", "Honoré", "Révéré", "Exalté"
L.MENU_TITLE       = "Freegor Guide - que voulez-vous suivre ?"
L.CURRENT_FMT      = "Guide actif : %s"
L.CAT_leveling     = "Montée de niveau"
L.CAT_mounts       = "Montures"
L.CAT_gold         = "Or et récolte"
L.CAT_reputation   = "Réputation"
L.CAT_achievements = "Hauts faits et collections"
L.NO_ACHIEVEMENTS  = "Ce client n'a pas de système de hauts faits : ces guides suivent des objectifs que le jeu peut vérifier (points de vol...)."
L.NO_GUIDES_IN_CAT = "Pas encore de guide dans cette catégorie pour votre personnage."
L.PROGRESS_FMT     = "étape %d/%d"
L.STEPS_FMT        = "%d étapes"
L.LOOP_HINT        = "Circuit : recommence au début une fois terminé."
L.MINIMAP_HINT     = "Clic gauche : choisir un guide. Clic droit : afficher/masquer le guide. Glisser pour déplacer."
L.QUEST_FMT    = "quête n°%d"

L.HELP = {
  "/freegor - afficher ou masquer la fenêtre du guide",
  "/freegor menu - choisir quoi suivre (niveau, montures, or, réputation...)",
  "/freegor next | prev - changer d'étape",
  "/freegor step <n> - aller à une étape",
  "/freegor arrow - afficher ou masquer la flèche",
  "/freegor auto - activer ou non l'acceptation/le rendu automatique des quêtes",
  "/freegor minimap - afficher ou masquer le bouton de la minicarte",
  "/freegor reset - réinitialiser la position de la fenêtre",
}
