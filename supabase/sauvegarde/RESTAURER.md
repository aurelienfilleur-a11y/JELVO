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

### 1. La paire de clés

```bash
age-keygen -o jelvo-sauvegarde.key
```

La commande affiche `Public key: age1…`.

- **la ligne `age1…`** remplace la dernière ligne de
  `supabase/sauvegarde/cle-publique.age`, et part dans le dépôt. C'est une clé
  publique : elle ne permet que de chiffrer ;
- **le fichier `jelvo-sauvegarde.key`** va dans votre gestionnaire de mots de
  passe, et **nulle part ailleurs**. Ni dans le dépôt, ni dans les secrets
  GitHub, ni sur votre disque.

> **Perdre cette clé, c'est perdre toutes les sauvegardes.** C'est la
> contrepartie assumée de la propriété qu'elle donne : le workflow ne détient
> que la clé publique, donc quelqu'un qui obtiendrait vos secrets GitHub
> pourrait écrire dans le bucket, jamais lire une sauvegarde.

Tant que la ligne est le gabarit, le workflow **s'arrête avant de dumper**.

### 2. Le bucket R2

Dans le tableau de bord Cloudflare, **R2 → Create bucket**. Un nom quelconque,
par exemple `jelvo-sauvegardes`. Puis **Manage R2 API Tokens → Create API
token**, permission **Object Read & Write**, borné à ce seul bucket.

Notez trois valeurs : l'**Account ID**, l'**Access Key ID** et la **Secret
Access Key**.

### 3. La rétention, posée une fois et tenue par R2

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
| `SUPABASE_DB_URL` | déjà posé — celui des migrations |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Project Settings → API → `service_role` |
| `R2_ACCOUNT_ID` | Cloudflare → R2 |
| `R2_ACCESS_KEY_ID` | le jeton de l'étape 2 |
| `R2_SECRET_ACCESS_KEY` | idem |
| `R2_BUCKET` | le nom du bucket |
| `HEALTHCHECK_URL` | l'URL de ping de l'étape 4 |

`SUPABASE_SERVICE_ROLE_KEY` contourne RLS : c'est la clé la plus puissante du
projet. Elle n'est lue que par ce workflow, qui ne tourne **jamais** sur une
pull request — même raison que le workflow des migrations, et c'est ce qui
rend son dépôt ici acceptable sur un dépôt public.

### 6. Le premier passage, et le contrôle qui ne s'automatise pas

Lancez le workflow à la main — **Actions → Sauvegarde de la base → Run
workflow**. Ne pas attendre 02:17 pour découvrir que la chaîne ne tourne pas :
c'est la leçon du jeton mort, déjà payée.

Puis, **une fois**, déchiffrez la sauvegarde vous-même :

```bash
aws s3 cp "s3://jelvo-sauvegardes/quotidien/<fichier>.tar.age" . \
  --endpoint-url "$R2"

supabase/sauvegarde/eprouver_restauration.sh <fichier>.tar.age \
  --cle jelvo-sauvegarde.key
```

**C'est le seul contrôle que l'épreuve nocturne ne peut pas faire.** Elle
restaure chaque nuit, mais sur le fichier *en clair*, avant chiffrement : le
runner ne détient que la clé publique. Que le fichier chiffré soit
déchiffrable par **votre** clé ne se prouve qu'ici.

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
