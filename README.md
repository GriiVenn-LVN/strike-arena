# Strike Arena

FPS tactique dans le navigateur (Three.js), solo contre des bots ou multijoueur.

## Jouer

- **Seul** : double-clique sur `index.html` (ou `strike-arena.html`). `three.min.js` doit rester dans le même dossier.
- **À plusieurs sur le même PC** : ouvre le jeu dans plusieurs onglets → *Jouer › Multijoueur* → « Même PC » → *Créer un salon* dans un onglet, *Rejoindre* avec le code dans les autres.
- **En ligne avec des amis** : publie le dossier (voir ci-dessous), envoie le lien, *Jouer › Multijoueur* → « En ligne » → crée un salon et donne le code. La connexion se fait directement entre navigateurs (WebRTC via PeerJS) ; une connexion internet est nécessaire.

## Publier sur GitHub Pages

1. Crée un dépôt sur GitHub et envoie-y ces fichiers : `index.html` et `three.min.js` suffisent pour jouer (`src/`, `tools/`, `build.sh` servent à modifier le jeu).
2. Sur GitHub : *Settings › Pages › Build and deployment* → *Deploy from a branch* → branche `main`, dossier `/ (root)`.
3. Le jeu est accessible à l'adresse `https://<ton-pseudo>.github.io/<nom-du-depot>/`.

## Modifier le jeu

Les sources sont dans `src/`. Après une modification, reconstruis le fichier final :

```bash
./build.sh
```

Pour tester avec un petit serveur local (utile pour le multijoueur entre onglets) : `perl tools/serve.pl 8765` puis ouvre `http://localhost:8765/`.
