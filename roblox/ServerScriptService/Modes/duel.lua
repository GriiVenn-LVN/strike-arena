--!strict
-- Modes/duel : Duel (web : src/8B_duel.js), 1 v 1 à 5 v 5 : manches de 60 s sans bombe ni réapparition, 6 s pour
-- choisir son arme (touche B, 16 000 à chaque manche), positions révélées à 20 s de la fin ; au temps, l'équipe
-- avec le plus de survivants puis le plus de points de vie gagne la manche. Toutes les règles sont dans Modes/rounds.
return require(script.Parent.rounds).make("duel")
