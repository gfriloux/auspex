# Tests manuels — plan v0.6.1

- [ ] Avec une instance Zabbix réelle : désactiver un trigger ayant un
  problème ouvert → relancer Auspex (`just mock` ne simule pas ce cas,
  nécessite une vraie instance ou un mock enrichi) → vérifier que le problème
  disparaît du cockpit au cycle de poll suivant, sans crash ni host vide
  résiduel.
- [ ] Vérifier qu'un problème dont le trigger reste actif n'est pas affecté
  (pas de régression sur l'affichage normal).
- [ ] `just ci` complet (fmt-check + lint + test) dans `nix develop`, non
  vérifiable dans le sandbox de préparation — à faire avant merge.
