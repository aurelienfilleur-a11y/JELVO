# Sauvegarder et restaurer la base Jelvo

L'offre gratuite de Supabase n'inclut **aucune** sauvegarde. Ce dossier en
tient une : `.github/workflows/sauvegarde-base.yml` exporte chaque nuit, et
dépose sur Cloudflare R2 un fichier chiffré.

Ce document sert deux fois : **la mise en service**, une fois, et **la
restauration**, le jour où elle sera nécessaire. La seconde partie se lit
d'abord quand on est pressé — elle est donc au milieu, pas à la fin.

---

## Ce qui est sauvegardé, et ce qui ne l'est pas

| Dans la sauvegarde | Hors de la sauvegarde |
| --- | --- |
| `public` : toutes les données de l'application | les **secrets** de la fonction Edge (clés VAPID) |
| `auth` : les comptes, donc l'identité de chacun | la planification `pg_cron` d'`envoyer-push` |
| `storage` : l'index des fichiers | les réglages du projet (confirmation d'e-mail, modèles) |
| **les fichiers eux-mêmes** des trois buckets | le journal d'audit de gotrue |

Les trois colonnes de droite se reposent à la main sur un projet neuf, et
elles sont décrites sous « Restaurer », étape 6. Aucune n'est une donnée
irremplaçable : ce sont des réglages, et ils sont écrits ici ou dans
`CLAUDE.md`.

**Les fichiers des buckets sont dans la sauvegarde**, et il faut le dire parce
que l'inverse est le piège courant : `storage.objects` ne porte que les
*chemins*. Un dump SQL seul perdrait tous les avatars, toutes les photos de
couverture et tous les messages vocaux en ayant l'air complet.

---

## Mise en service — à faire une fois

**Tout se fait depuis un iPhone, sauf un contrôle.** Le tableau dit où chaque
geste se passe, parce que « ouvrez un terminal » n'est pas une instruction
utilisable quand on n'en a pas.

| Geste | Où |
| --- | --- |
| 1. la paire de clés | **gestionnaire de mots de passe**, sur le téléphone — voir ci-dessous |
| 2. le bucket R2 et son jeton | dashboard Cloudflare, dans Safari |
| 3. les deux règles de rétention | dashboard R2, dans Safari — **pas en ligne de commande** |
| 4. l'alerte | healthchecks.io, dans Safari |
| 5. les sept secrets | réglages du dépôt sur github.com, dans Safari |
| 6. le premier passage | **Actions → Run workflow**, dans Safari |
| 7. le déchiffrement de contrôle | **demande un terminal** — voir § 7 |

Les gestes 2, 4 et 5 ne peuvent pas être faits à votre place : ils demandent
des comptes qui sont les vôtres, et le geste 5 porte des valeurs qu'aucun
assistant ne doit voir.

### 1. La paire de clés

Il faut une paire asymétrique : la moitié **publique** part dans ce dépôt, la
moitié **privée** reste chez vous. C'est elle qui fait que le workflow peut
écrire des sauvegardes sans pouvoir les lire.

> **La moitié privée ne doit jamais passer par une conversation avec un
> assistant.** Pas par prudence de façade : cette session a un accès en
> écriture au dépôt, donc de quoi écrire un workflow qui exfiltre vos secrets
> GitHub, donc le jeton R2. Si elle avait *en plus* vu la clé privée, un seul
> endroit compromis donnerait les sauvegardes **et** de quoi les lire. Les
> deux moitiés ne doivent pas se rencontrer, et c'est toute l'architecture.

**La forme recommandée, et la seule qui ne demande aucun terminal : une clé
SSH ed25519 produite par votre gestionnaire de mots de passe.** 1Password et
Bitwarden savent créer un élément « clé SSH » et en générer la paire sur
l'appareil ; la moitié privée ne quitte jamais le coffre, et c'est la moitié
publique — `ssh-ed25519 AAAAC3Nza…` — qu'on copie dans
`supabase/sauvegarde/cle-publique.age` par l'éditeur web de GitHub.

`age` accepte cette forme : vérifié aller et retour, contrôle négatif
compris — chiffrement vers la clé publique SSH, déchiffrement par la clé
privée correspondante, refus d'une clé étrangère.

Et elle a un avantage propre, qui n'est pas de la commodité : la paire étant
produite **par** le gestionnaire, le défaut qu'aucun contrôle automatique ne
peut voir — une clé publique dont plus personne ne détient la moitié privée —
devient invraisemblable.

> **Attention au gestionnaire.** « Mots de passe » d'Apple et le trousseau
> iCloud ne génèrent pas de clés SSH. Si c'est celui que vous utilisez, il
> faut passer par l'un des deux autres chemins ci-dessous. Je n'ai pas pu
> éprouver ces applications d'ici : ce qui est vérifié, c'est qu'`age` accepte
> le résultat, pas que telle version sache le produire.

**Deuxième chemin, si le gestionnaire ne sait pas faire de clé SSH : un vrai
terminal sur l'iPhone.** `iSH` (App Store, gratuit) fait tourner Alpine, où
`apk add age` donne `age-keygen`. Cela vaut aussi pour le geste 7, qu'il
débloque du même coup. Pas éprouvé d'ici non plus.

**Troisième chemin, à n'employer que si les deux premiers échouent : une
phrase de passe au lieu d'une paire.** `age` sait chiffrer vers une phrase de
passe, que n'importe quel gestionnaire sait produire. Le coût est précis, et
il faut le connaître avant de choisir : la phrase devant servir à chiffrer,
elle vivrait dans les secrets GitHub, et **une compromission de GitHub
donnerait alors les sauvegardes et de quoi les lire**. Un jeton R2 qui fuite
seul resterait sans effet, ce qui est déjà la moitié du bénéfice. Ce chemin
demande une modification du workflow, qui n'est pas écrite : demandez-la
plutôt que de l'improviser.

Dans tous les cas :

- **la moitié publique** remplace la dernière ligne de
  `supabase/sauvegarde/cle-publique.age`, et part dans le dépôt ;
- **la moitié privée** va dans le gestionnaire de mots de passe, et **nulle
  part ailleurs**.

> **Perdre la moitié privée, c'est perdre toutes les sauvegardes.** C'est la
> contrepartie assumée de la propriété qu'elle donne.

Tant que la ligne est le gabarit, le workflow **s'arrête avant de dumper**. Le
juge de la forme est `age` lui-même : le workflow chiffre un canari vers le
fichier avant tout le reste, si bien qu'une ligne tronquée par un
copier-coller est refusée et nommée.

### 2. Le bucket R2

Dans le tableau de bord Cloudflare, **R2 → Create bucket**. Un nom quelconque,
par exemple `jelvo-sauvegardes`. Puis **Manage R2 API Tokens → Create API
token**, permission **Object Read & Write**, borné à ce seul bucket.

Notez trois valeurs : l'**Account ID**, l'**Access Key ID** et la **Secret
Access Key**.

### 3. La rétention, posée une fois et tenue par R2

**Depuis Safari, sans ligne de commande** : R2 → votre bucket → **Settings →
Object lifecycle rules → Add rule**. Deux règles à créer, une par préfixe :

| Nom | Préfixe | Action |
| --- | --- | --- |
| `quotidien-30-jours` | `quotidien/` | supprimer après **30** jours |
| `mensuel-12-mois` | `mensuel/` | supprimer après **365** jours |

Le préfixe compte : sans lui, la règle des 30 jours emporterait aussi les
mensuelles, et la rétention longue n'existerait plus. Les deux noms sont
libres — le workflow ne les lit pas, il relève seulement qu'**une**
configuration de cycle de vie existe.

<details>
<summary>La même chose en ligne de commande, si vous avez un terminal</summary>

```bash
export AWS_ACCESS_KEY_ID=…
export AWS_SECRET_ACCESS_KEY=…
export AWS_DEFAULT_REGION=auto
R2=https://<ACCOUNT_ID>.r2.cloudflarestorage.com

cat > cycle.json <<'JSON'
{"Rules": [
  {"ID": "quotidien-30-jours",
   "Status": "Enabled",
   "Filter": {"Prefix": "quotidien/"},
   "Expiration": {"Days": 30}},
  {"ID": "mensuel-12-mois",
   "Status": "Enabled",
   "Filter": {"Prefix": "mensuel/"},
   "Expiration": {"Days": 365}}
]}
JSON

aws s3api put-bucket-lifecycle-configuration \
  --endpoint-url "$R2" --bucket jelvo-sauvegardes \
  --lifecycle-configuration file://cycle.json
```

</details>

**La rétention est tenue par le stockage, et c'est voulu.** Une boucle de
suppression dans le workflow tournerait chaque nuit avec les droits
d'effacer ; un préfixe mal écrit viderait le bucket. R2 n'a pas besoin qu'on
lui donne ce pouvoir.

Trente quotidiennes et douze mensuelles : ~1,3 Gio avec la taille actuelle,
largement sous les 10 Gio gratuits. Le quotidien seul ne protège pas d'un
dégât qu'on met six semaines à remarquer.

Le workflow **relève** la présence de ces règles à chaque passage et avertit si
elles manquent — ce qui n'est pas relevé n'est pas vérifié.

### 4. L'alerte

Créez un compte sur **healthchecks.io** (gratuit), puis un *check* nommé
`jelvo-sauvegarde`, période **1 jour**, grâce **2 heures**. Copiez son URL de
ping.

**L'alerte porte sur l'absence, pas sur l'échec**, et c'est le point qui
compte. Deux mécanismes arrêtent un workflow nocturne sans jamais le mettre
au rouge :

- GitHub **désactive un workflow planifié après 60 jours sans activité** sur
  un dépôt public — il n'y a alors plus de run du tout ;
- un projet Supabase gratuit **se met en pause après 7 jours d'inactivité**, et
  une base en pause ne se dump pas.

Une alerte branchée sur l'échec ne partirait dans aucun des deux cas.
Healthchecks écrit quand le ping **n'arrive pas**, ce qui couvre l'échec, la
désactivation du cron et la pause du projet d'un seul mécanisme.

### 5. Les secrets

Réglages du dépôt → **Secrets and variables → Actions** :

| Secret | Où le trouver |
| --- | --- |
| `SUPABASE_DB_URL` | **déjà posé** — celui des migrations, rien à refaire |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Project Settings → API → `service_role` |
| `R2_ACCOUNT_ID` | Cloudflare → R2 → **Account ID** : 32 caractères hexadécimaux, **et non l'endpoint** |
| `R2_ACCESS_KEY_ID` | le jeton de l'étape 2 |
| `R2_SECRET_ACCESS_KEY` | idem, visible **une seule fois** à la création du jeton |
| `R2_BUCKET` | le nom du bucket, seul (`jelvo-sauvegardes`), sans `s3://` ni chemin |
| `HEALTHCHECK_URL` | l'URL de ping de l'étape 4 — **le seul facultatif**, voir ci-dessous |

**`R2_ACCOUNT_ID` n'est pas l'endpoint**, et c'est le piège de cette liste :
le dashboard donne l'URL complète sous la main, le workflow attend seulement
le sous-domaine. Si vous avez
`https://3f8a…e6f7.r2.cloudflarestorage.com`, le secret vaut `3f8a…e6f7` —
sans `https://`, sans `.r2.cloudflarestorage.com`. Le workflow refuse
désormais une URL en le disant, plutôt que de bâtir une adresse absurde et de
laisser l'échec parler de résolution DNS.

**`HEALTHCHECK_URL` est le seul dont l'absence n'arrête rien** : le job
avertit et continue. Les sauvegardes partent donc, et c'est l'**alerte** qui
manque — or elle couvre les deux pannes qui n'allument jamais le rouge : le
cron désactivé après 60 jours, et le projet Supabase mis en pause après 7
jours d'inactivité. Sans elle, le silence ne se distingue pas du succès. À
poser dès que le compte existe ; les six autres sont nécessaires.

`SUPABASE_SERVICE_ROLE_KEY` contourne RLS : c'est la clé la plus puissante du
projet. Elle n'est lue que par ce workflow, qui ne tourne **jamais** sur une
pull request — même raison que le workflow des migrations, et c'est ce qui
rend son dépôt ici acceptable sur un dépôt public.

### 6. Le premier passage

Lancez le workflow à la main — **Actions → Sauvegarde de la base → Run
workflow**, depuis Safari. Ne pas attendre 02:17 pour découvrir que la chaîne
ne tourne pas : c'est la leçon du jeton mort, déjà payée.

Le résumé du job dit ce qu'il a fait : la majeure du serveur, le nombre de
tables et de fichiers, le verdict de l'épreuve de restauration, la taille de
l'archive chiffrée, l'objet déposé. **C'est là que se lit la réussite**, pas
dans le bucket.

### 7. Le déchiffrement de contrôle — le seul geste qui demande un terminal

**C'est le seul contrôle que l'épreuve nocturne ne peut pas faire.** Elle
restaure chaque nuit, mais sur le fichier *en clair*, avant chiffrement : le
runner ne détient que la clé publique. Que le fichier chiffré soit
déchiffrable par **votre** moitié privée ne se prouve qu'une fois, à la main.

```bash
aws s3 cp "s3://jelvo-sauvegardes/quotidien/<fichier>.tar.age" . \
  --endpoint-url "$R2"

supabase/sauvegarde/eprouver_restauration.sh <fichier>.tar.age \
  --cle <votre moitié privée>
```

La moitié privée peut être la clé `age` (`jelvo-sauvegarde.key`) **ou la clé
privée SSH** exportée du gestionnaire de mots de passe : `age` accepte les
deux comme identité.

**Depuis un iPhone seul, ce geste n'est pas faisable sans installer un
terminal** (`iSH`, voir § 1). Deux façons de vivre avec, et il faut choisir en
connaissance de cause :

- **le faire plus tard**, depuis n'importe quel ordinateur emprunté, une fois.
  Rien n'en dépend pour que les sauvegardes soient correctes : il ne prouve
  pas la sauvegarde, il prouve **votre clé** ;
- **s'en passer**, à condition que la paire vienne du gestionnaire de mots de
  passe (§ 1). C'est l'argument décisif pour cette forme-là : le risque que ce
  contrôle couvre est « une clé publique dont plus personne ne détient la
  moitié privée », et une paire produite par le coffre où elle est rangée ne
  peut guère tomber dans ce cas.

Ce qu'on perd en s'en passant mérite d'être dit : si la ligne du dépôt portait
la clé de **quelqu'un d'autre** — un copier-coller depuis la mauvaise fiche —
tout passerait au vert et rien ne le dirait. C'est le seul scénario que ni le
workflow ni l'épreuve ne peuvent attraper.

À refaire si vous changez un jour de clé.

---

## Restaurer

### 1. Récupérer et juger la sauvegarde

```bash
aws s3 ls "s3://jelvo-sauvegardes/quotidien/" --endpoint-url "$R2"
aws s3 cp "s3://jelvo-sauvegardes/quotidien/<fichier>.tar.age" . --endpoint-url "$R2"

supabase/sauvegarde/eprouver_restauration.sh <fichier>.tar.age \
  --cle jelvo-sauvegarde.key
```

Le script monte un cluster jetable, restaure, et confronte le résultat à
l'inventaire relevé au moment du dump. **Faites-le avant de toucher à quoi que
ce soit** : il dit en trente secondes si ce fichier vaut quelque chose, et
distingue une archive abîmée d'une sauvegarde saine.

Pour inspecter sans restaurer :

```bash
age --decrypt -i jelvo-sauvegarde.key -o clair.tar <fichier>.tar.age
tar -xf clair.tar && cat jelvo/MANIFESTE.txt
pg_restore --list jelvo/base.dump | head -40
```

### 2. Un projet Supabase neuf

Créez-le, et notez son **URL**, sa clé **publishable** et sa chaîne de
connexion. La région n'a pas d'importance fonctionnelle.

### 3. Restaurer la base

```bash
# La majeure doit être au moins celle du manifeste.
pg_restore --dbname="$NOUVELLE_URL" --no-owner --clean --if-exists \
  --jobs=4 jelvo/base.dump
```

`pg_restore` **sortira en échec sur des lignes qui ne sont pas des erreurs** :
des objets déjà posés par Supabase, des extensions qu'il ne peut pas créer.
Lisez le journal avant de conclure — le rouge ne désigne pas l'étape qui
compte, et c'est déjà la règle du workflow des migrations.

Le verdict est l'inventaire, pas le code de sortie :

```bash
psql "$NOUVELLE_URL" -At -v ON_ERROR_STOP=1 \
  -f supabase/sauvegarde/inventaire.sql | sort > apres.txt
diff <(grep '^jelvo	' jelvo/inventaire.txt | sort) \
     <(grep '^jelvo	' apres.txt)
```

### 4. Faire converger le schéma

Les migrations sont **idempotentes** et vivent dans le dépôt. Elles sont donc
le moyen de rattraper ce que la restauration n'a pas posé — publication
`supabase_realtime`, privilèges, politiques de stockage :

```bash
SUPABASE_DB_URL="$NOUVELLE_URL" supabase/verification/appliquer.sh
```

C'est une conséquence heureuse de la façon dont ce projet est fait : **le dump
porte les données, le dépôt porte le schéma.** Les données sont
irremplaçables, le schéma se rejoue.

### 5. Re-téléverser les fichiers des buckets

Les buckets doivent exister d'abord — `avatars`, `group-photos` et
`chat-media`, ce dernier **privé**. Puis :

```bash
export SUPABASE_URL=https://<nouveau>.supabase.co
export SERVICE_ROLE=<clé service_role du nouveau projet>

find jelvo/fichiers -type f | while read -r f; do
  rel=${f#jelvo/fichiers/}
  bucket=${rel%%/*}
  chemin=${rel#*/}
  curl -fsS -X POST \
    -H "Authorization: Bearer $SERVICE_ROLE" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$f" \
    "$SUPABASE_URL/storage/v1/object/$bucket/$chemin" > /dev/null \
    && echo "OK    $rel" || echo "ÉCHEC $rel"
done
```

Les lignes de `storage.objects` sont déjà restaurées par l'étape 3 : ce sont
les **octets** qu'on repose ici. Un fichier manquant donnerait une bulle qui
annonce une photo introuvable.

### 6. Les réglages qui ne sont pas dans la base

| À reposer | Où |
| --- | --- |
| `SUPABASE_URL` et `SUPABASE_ANON_KEY` | bloc `env` de `deploy-web.yml` |
| `SUPABASE_DB_URL` | secrets du dépôt — et de ce workflow |
| clés VAPID | Supabase → Edge Functions → Secrets |
| planification d'`envoyer-push` | Supabase → Integrations → Cron, `* * * * *` |
| `{{ .Token }}` dans le modèle d'e-mail | Supabase → Authentication → Email Templates |
| un modérateur | `supabase/designer_moderateur.sql` |

Les quatre dernières lignes sont les prérequis manuels déjà listés dans
`CLAUDE.md` : une restauration les remet tous à zéro.

### 7. Le contrôle final

Ouvrez l'application, connectez-vous, et vérifiez qu'une conversation affiche
ses messages **et** ses médias. C'est le seul contrôle qui porte sur les deux
moitiés de la sauvegarde à la fois.

---

## Ce que ce dispositif ne couvre pas

- **Le point de restauration est la nuit précédente.** Une perte à 20 h coûte
  la journée. Un vrai PITR est une fonctionnalité payante de Supabase, et
  aucun workflow nocturne ne s'en approche.
- **Rien ne protège d'une sauvegarde juste d'un état déjà abîmé.** Si une
  migration fautive détruit des données un mardi, la sauvegarde du mercredi
  porte le dégât. Les trente quotidiennes et les douze mensuelles sont là pour
  cela : remonter avant.
- **L'épreuve nocturne tourne sur un cluster nu**, pas sur un projet Supabase.
  Elle prouve que les données, les privilèges, les politiques, les
  déclencheurs et les types énumérés traversent le dump intacts. Elle ne
  prouve pas qu'un projet Supabase neuf acceptera tout sans un mot — l'étape 3
  dit d'ailleurs de lire le journal.
- **La première restauration réelle n'a jamais été faite.** Elle ne peut pas
  l'être sans créer un second projet ; ce qui est éprouvé automatiquement,
  c'est tout ce qui peut l'être sans.
- **La déchiffrabilité par votre moitié privée ne se prouve pas sur le
  runner**, qui ne détient que la publique. C'est la propriété qu'on cherche,
  donc ce n'est pas un oubli — mais c'est le geste 7, et il demande un
  terminal. Depuis un iPhone seul, il reste en attente ; ce qui le rend
  supportable est que la paire vienne du gestionnaire de mots de passe.
