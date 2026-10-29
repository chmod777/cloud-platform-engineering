# Cloud Platform Engineering — GCP lab

Infrastructure de développement : projet `cloud-platform-engineering-hs`.

## Organisation et protection

`terraform/environments/dev/` conserve un seul état local pour cette première étape.
`main.tf`, `firewall.tf`, `iam.tf` et `service-account.tf` décrivent le socle permanent.
`compute.tf` contient la VM temporaire, désactivée par défaut (`lab_enabled = false`).
Les ressources permanentes portent `prevent_destroy`. Cette protection dépend de la
présence des blocs dans la configuration : ne pas supprimer ces blocs.
Ne jamais lancer un destroy global. Aucun déplacement d'état n'est nécessaire ici.
Une séparation future en deux états nécessitera une migration sauvegardée et vérifiée.

## Prérequis

Terraform >= 1.5, Python 3, gcloud authentifié, et accès GCP/ADC pour Terraform.
GitHub n'est pas requis pour utiliser le lab. Après un nouveau clonage, restaurer
l'état existant de façon sécurisée avant tout plan : ne pas appliquer avec un état vide.
Initialiser les fournisseurs avec `terraform -chdir=terraform/environments/dev init -lockfile=readonly`.

## Commandes depuis la racine du dépôt

```bash
./scripts/lab-status
./scripts/lab-start --plan
./scripts/lab-start
./scripts/lab-stop --plan
./scripts/lab-stop
```

Start et stop calculent un plan complet et refusent tout changement autre que la
création ou suppression de `google_compute_instance.mgmt_vm[0]`.
Un remplacement ou un changement du réseau/IAM bloque l'opération.
Les plans sont stockés temporairement avec accès privé, puis effacés.
Seul le plan vérifié est appliqué, après saisie de `yes` ; `--plan` n'applique rien.
Une deuxième exécution doit produire zéro changement si l'état distant est conforme.
Un verrou local empêche les scripts de fonctionner simultanément ; Terraform garde
son verrou d'état. Après un crash, vérifier qu'aucun script ne tourne avant de
retirer un éventuel dossier `.lab-lock` résiduel.

`lab-stop` supprime la VM et son disque de démarrage (`auto_delete = true`) ; il ne
se contente pas d'éteindre la VM. Il ne nettoie pas d'autres ressources du projet.
`lab-status` liste VM, disques et IP réservées ; une erreur d'accès est une erreur,
pas la preuve d'un projet vide. Ce n'est pas un inventaire de tous les services.

## Coûts et fin de session

La VM e2-micro et son disque pd-standard de 10 Go en europe-west1 sont facturables
sur les crédits d'essai. Pas d'IP publique ni de Cloud NAT ajouté par ces scripts.
Vérifier dans Billing le solde des crédits, leur expiration et le type de compte
avant chaque démarrage ; aucune vérification automatique fiable du solde n'est intégrée.
Choisir une durée courte puis exécuter lab-stop et lab-status. Aucun arrêt automatique
n'est installé. Les budgets d'alerte ne plafonnent pas les dépenses Compute Engine.
Aucune garantie de non-dépassement ne peut être déduite de ces scripts.

- Free Tier : https://docs.cloud.google.com/free/docs/free-cloud-features
- Budgets : https://docs.cloud.google.com/billing/docs/how-to/budgets
- Tarifs VM : https://cloud.google.com/compute/vm-instance-pricing
- Tarifs disques : https://cloud.google.com/compute/disks-image-pricing

Ne pas publier les états, sauvegardes, plans ou identifiants. Le fichier de verrouillage
des fournisseurs est versionné. Conserver les sauvegardes d'état hors du dépôt en lieu sûr.
La règle HTTPS actuelle autorise 10.10.2.0/24 ; la VM est dans 10.10.3.0/24.
Cette règle n'est pas modifiée dans cette étape.

## Vérification locale des garde-fous

`python3 -m unittest discover -s tests -v`
