# LAB 3 — Résultats du 29 octobre 2026

Cycle réel de création, publication, déploiement, test et suppression réalisé
sur le projet `cloud-platform-engineering-hs`, région `europe-west9` (Paris).
Contrôle final effectué vers 11 h 33, heure de Paris.

## Ce qui a été appris et vérifié

1. **FastAPI** expose `/health` et `/`, avec APP_ENV pour configurer l'environnement.
   Trois tests vérifient santé, configuration et route inconnue.
2. **Docker** assemble l'application et son environnement Python. L'image construite
   et testée est Linux amd64, exécutée comme utilisateur 10001. Deux appels HTTP
   locaux ont validé la santé et APP_ENV=docker. Le conteneur a été arrêté.
3. **Artifact Registry** stocke l'image privée. Publication effectuée avec le digest
   `sha256:47635b9c5738f40b3f04d8ee891af414d35642dc7e1659aac9d4ce2a1a9842d7`.
4. **Terraform** a créé le registre, le compte de service sans rôle projet et le
   service Cloud Run dans un état distinct des LAB 1 et 2. Les plans contrôlés
   n'ont modifié aucune ressource des labs précédents.
5. **Cloud Run** a exécuté cette image : `/health` a retourné HTTP 200 et
   `{"status":"ok"}` ; `/` a retourné HTTP 200 avec APP_ENV=lab3.
6. **IAM** a refusé l'accès anonyme (HTTP 403) et accepté le jeton utilisateur.
   Aucune liaison allUsers n'a été créée ; les permissions héritées de l'opérateur
   ont suffi. L'URL réseau est publique, l'invocation exige une identité autorisée.
7. **Logs** : démarrage Uvicorn et écoute sur 0.0.0.0:8080 observés.
8. **Nettoyage** : suppression du service, du registre avec ses images et du compte
   de service. État LAB 3 vide ; second plan de nettoyage sans changement.

## Vérifications finales

- 9 tests LAB 3 réussis (3 API et 6 protections de plan).
- 7 tests LAB 2 réussis ; configuration LAB 2 inchangée.
- Terraform validate et fmt : réussis ; vérification des scripts et des espaces Git : réussie.
- Liste des services Cloud Run à Paris : vide.
- Liste des registres Artifact Registry dans toutes les régions : vide.
- Liste des comptes de service filtrée sur lab3-api-runtime : vide.
- Inventaires Compute Engine : aucune VM, aucun disque, aucune IP réservée.
- Colima arrêté ; Docker/Colima/Buildx installés et image conservée localement.
- API Run, Artifact Registry et IAM laissées activées, sans ressource LAB 3 active.

## Facturation et limites

L'utilisateur a confirmé dans la console : compte **Essai gratuit**, crédits disponibles et validité suffisante. Le lien de facturation et le compte ouvert
ont été vérifiés par les API ; celles-ci n'ont pas attesté le solde ni l'essai.
Aucun passage au compte payant, modification de moyen de paiement ou de liaison
 de facturation n'a été effectué.

Le cycle consomme potentiellement des crédits (calcul, stockage, requêtes).
Le coût exact et le nouveau solde ne sont pas connus. Vérifier les rapports après
leur actualisation. Les logs peuvent persister après suppression. Cet inventaire
ne constitue pas un audit exhaustif de tous les produits GCP.

Minimum zéro et maximum une instance configurés, sans test de charge ni mesure
 du retour à zéro : le service a été supprimé immédiatement après les tests.
Pas de CI/CD, arrêt automatique ni plafond financier programmatique.
Conserver le statut d'essai : Google indique qu'aucun débit ne survient sans
passage manuel au compte payant. Sur un compte payant, des crédits seuls ne
protègent pas d'un dépassement.

Sources :
- https://cloud.google.com/signup-faqs
- https://docs.cloud.google.com/run/docs/container-contract

## Rejouer le lab

Suivre `lab3/README.md` depuis la racine du dépôt. Les commandes lifecycle affichent
un plan par défaut ; `--apply` applique uniquement après les confirmations.
Toujours terminer par `./lab3/lifecycle clean --apply`, même après un échec partiel.
Le dépôt cloud ayant été supprimé, republier l'image avant tout nouveau déploiement.
