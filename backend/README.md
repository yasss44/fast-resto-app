# FAST Backend API

Node.js + Express + TypeScript + Prisma + PostgreSQL (Neon)

Serveur backend pour l'application FAST Click & Collect — commande de restaurant, livraison, et commandes de groupe.

## Stack

- **Runtime** : Node.js ≥ 18
- **Framework** : Express 4 (TypeScript)
- **ORM** : Prisma 6 (PostgreSQL via Neon)
- **Validation** : Zod 3
- **Auth** : JWT (jsonwebtoken) + bcryptjs
- **Sécurité** : helmet, CORS, express-rate-limit

## Installation

```bash
cd backend
npm install
```

## Configuration

Copier `.env.example` vers `.env` et ajuster les valeurs :

```bash
cp .env.example .env
```

### Variables importantes

| Variable | Description | Défaut |
|----------|-------------|--------|
| `DATABASE_URL` | URL de connexion PostgreSQL (Neon) | requis |
| `JWT_SECRET` | Clé secrète JWT | `fallback-secret` |
| `JWT_EXPIRES_IN` | Durée du token | `24h` |
| `PORT` | Port du serveur | `3000` |
| `CORS_ORIGIN` | Origines CORS (séparées par `,`) | `http://localhost:3000,http://localhost:5173` |
| `SERVICE_FEE` | Frais de service par commande (€) | `1.50` |
| `STRIPE_SECRET_KEY` | Clé secrète Stripe | optionnel |
| `STRIPE_WEBHOOK_SECRET` | Secret webhook Stripe | optionnel |
| `STRIPE_SUCCESS_URL` | URL de succès checkout (deep link app) | `fast://checkout/success?session_id={CHECKOUT_SESSION_ID}` |
| `STRIPE_CANCEL_URL` | URL d'annulation checkout | URL web fallback |
| `BCRYPT_ROUNDS` | Rounds de hash bcrypt | `12` |
| `MAX_FAILED_LOGINS` | Tentatives avant verrouillage | `5` |
| `LOCKOUT_MINUTES` | Durée verrouillage compte (min) | `15` |

## Base de données

```bash
# Générer le client Prisma
npx prisma generate

# Appliquer le schéma (dev)
npx prisma db push

# Créer une migration
npx prisma migrate dev --name init

# Seed la base de données (données de test)
npm run db:seed

# Lancer Prisma Studio (interface graphique DB)
npm run db:studio
```

## Développement

```bash
npm run dev
```

Le serveur démarre sur `http://localhost:3000` avec rechargement automatique (tsx watch).

## Production

```bash
npm run build
npm start
```

## Règles Générales de l'API

- **Authentification** : Envoyer `Authorization: Bearer <token>` dans les en-têtes
- **Format réponses erreur** : `{ "error": "Message", "details": [...] }` (details présent pour erreurs Zod)
- **Codes HTTP** :
  - `200` Succès
  - `201` Création
  - `400` Validation / requête invalide
  - `401` Non authentifié
  - `403` Accès refusé (rôle insuffisant)
  - `404` Ressource introuvable
  - `409` Conflit (ex: email déjà utilisé)
  - `429` Trop de requêtes (rate limit)
  - `500` Erreur interne
- **Rate limiting** :
  - Auth : 20 req / 15 min par IP
  - Général : 100 req / 1 min par IP

## API Endpoints

### 🔐 Auth

| Méthode | Endpoint | Auth | Rôle | Description |
|---------|----------|------|------|-------------|
| POST | `/api/auth/register` | — | — | Inscription (email, password, name, phone?, role?) |
| POST | `/api/auth/login` | — | — | Connexion → token JWT + user |
| GET | `/api/auth/me` | ✅ | — | Profil connecté avec son restaurant |
| PATCH | `/api/auth/profile` | ✅ | — | Modifier nom / téléphone |
| POST | `/api/auth/logout` | ✅ | — | Déconnexion (invalide tous les tokens) |

**Réponse login :**
```json
{
  "token": "eyJhbGci...",
  "user": {
    "id": "clxx...",
    "name": "Jean",
    "email": "jean@ex.com",
    "phone": "0612345678",
    "role": "CLIENT",
    "points": 0
  }
}
```

---

### 🏪 Restaurants

| Méthode | Endpoint | Auth | Rôle | Description |
|---------|----------|------|------|-------------|
| GET | `/api/restaurants` | — | — | Liste restaurants (filtres: `category`, `search`, `dietary`) |
| GET | `/api/restaurants/:id` | — | — | Détail d'un restaurant |
| POST | `/api/restaurants` | ✅ | RESTAURANT | Créer son restaurant |
| PATCH | `/api/restaurants/:id` | ✅ | RESTAURANT | Modifier son restaurant |
| GET | `/api/restaurants/account/mine` | ✅ | RESTAURANT | Mon restaurant (propriétaire) |
| POST | `/api/restaurants/toggle-rush` | ✅ | RESTAURANT | Activer/désactiver le mode rush |

---

### 📋 Menu

| Méthode | Endpoint | Auth | Rôle | Description |
|---------|----------|------|------|-------------|
| GET | `/api/menu/restaurant/:restaurantId` | — | — | Liste des articles du menu |
| POST | `/api/menu/restaurant/:restaurantId` | ✅ | RESTAURANT | Ajouter un article |
| PATCH | `/api/menu/:id` | ✅ | RESTAURANT | Modifier un article |
| DELETE | `/api/menu/:id` | ✅ | RESTAURANT | Supprimer un article |

---

### 🛒 Commandes

| Méthode | Endpoint | Auth | Rôle | Description |
|---------|----------|------|------|-------------|
| POST | `/api/orders` | ✅ | — | Passer commande (redirige vers Stripe) |
| GET | `/api/orders/mine` | ✅ | — | Mes commandes (filtre: `status`) |
| GET | `/api/orders/:id` | ✅ | CLIENT/RESTAURANT | Détail d'une commande (propriétaire ou restaurant) |
| PATCH | `/api/orders/:id/tracking` | ✅ | CLIENT | Mise à jour GPS (`gpsProgress` 0-1, `isReadyAtEntrance`) |
| POST | `/api/orders/:id/cancel` | ✅ | — | Annuler ma commande (remboursement Stripe si PLACED+PAID) |
| GET | `/api/orders/restaurant` | ✅ | RESTAURANT | Commandes du restaurant (filtre: `status`) |
| PATCH | `/api/orders/:id/status` | ✅ | RESTAURANT | Mettre à jour le statut (transitions validées) |
| POST | `/api/orders/:id/verify-pickup` | ✅ | RESTAURANT | Vérifier le token QR et compléter la commande |

**Statuts commande :** `PLACED → PREPARING → READY_FOR_PICKUP → COMPLETED` | `CANCELLED`

Les commandes payées reçoivent un `pickupToken` unique (`FAST-<hex>`) pour le retrait QR.

---

### 💳 Paiements (Stripe)

| Méthode | Endpoint | Auth | Rôle | Description |
|---------|----------|------|------|-------------|
| POST | `/api/payments/checkout-session` | ✅ | — | Créer une session Stripe Checkout |
| POST | `/api/payments/checkout-session/:sessionId/confirm` | ✅ | — | Confirmer paiement et créer la commande |
| POST | `/api/payments/webhook` | — | — | Webhook Stripe (`checkout.session.completed`) |
| GET | `/api/payments/checkout/success` | — | — | Page web fallback succès |
| GET | `/api/payments/checkout/cancel` | — | — | Page web fallback annulation |
| POST | `/api/payments/connect/account-link` | ✅ | RESTAURANT | Lancer onboarding Stripe Connect |
| GET | `/api/payments/connect/status` | ✅ | RESTAURANT | Statut du compte Connect |

Le subtotal inclut les suppléments (`selectedOptions` = IDs de `MenuItemSupplement`). Les articles indisponibles sont rejetés au checkout.

---

### ⭐ Avis

| Méthode | Endpoint | Auth | Rôle | Description |
|---------|----------|------|------|-------------|
| GET | `/api/reviews/restaurant/:restaurantId` | — | — | Avis d'un restaurant |
| POST | `/api/reviews/restaurant/:restaurantId` | ✅ | — | Poster un avis (commande complétée requise) |

---

### 🔔 Notifications

| Méthode | Endpoint | Auth | Rôle | Description |
|---------|----------|------|------|-------------|
| GET | `/api/notifications` | ✅ | — | Liste des notifications |
| POST | `/api/notifications` | ✅ | — | Créer une notification |
| POST | `/api/notifications/read-all` | ✅ | — | Marquer tout comme lu |
| PATCH | `/api/notifications/:id/read` | ✅ | — | Marquer une notification comme lue |
| DELETE | `/api/notifications/:id` | ✅ | — | Supprimer une notification |
| DELETE | `/api/notifications` | ✅ | — | Tout effacer |

---

### 📊 Statistiques

| Méthode | Endpoint | Auth | Rôle | Description |
|---------|----------|------|------|-------------|
| GET | `/api/stats` | ✅ | RESTAURANT | Stats du restaurant (volume, CA, tendances) |
| GET | `/api/stats/export?period=30` | ✅ | RESTAURANT | Export CSV du CA journalier (7, 30 ou 90 jours) |

---

### 👥 Commandes de Groupe

| Méthode | Endpoint | Auth | Rôle | Description |
|---------|----------|------|------|-------------|
| POST | `/api/groups` | ✅ | — | Créer un groupe (génère un code d'invite) |
| POST | `/api/groups/join` | ✅ | — | Rejoindre un groupe via son code |
| GET | `/api/groups/mine` | ✅ | — | Mes groupes |
| GET | `/api/groups/:id` | ✅ | — | Détail d'un groupe avec ses membres |
| GET | `/api/groups/:id/cart` | ✅ | — | Paniers de tous les membres (sanitisés) |
| PUT | `/api/groups/:id/cart` | ✅ | — | Sauvegarder mon panier (`{ items: cartItem[] }`) |
| PATCH | `/api/groups/:id/member` | ✅ | — | Mettre à jour mon statut membre (utilise le panier serveur si existant) |
| PATCH | `/api/groups/:id/payment-status` | ✅ | — | Marquer READY/DRAFT pour paiement |
| POST | `/api/groups/:id/lock` | ✅ | HOST | Verrouiller le groupe |
| POST | `/api/groups/:id/submit` | ✅ | HOST | Soumettre le groupe au restaurant |
| POST | `/api/groups/:id/leave` | ✅ | — | Quitter un groupe (host → annulation) |

**Codes d'invite :** Format `FAST-XXXXXX`. Généré automatiquement à la création.

**Rôles membre :** `HOST` (créateur) | `MEMBER` (participant)

**Statuts membre paiement :** `DRAFT → READY → PAID`

**Statuts groupe :** `OPEN → LOCKED → SUBMITTED → COMPLETED` | `CANCELLED`

---

### 🚚 Livraisons (Livreur)

| Méthode | Endpoint | Auth | Rôle | Description |
|---------|----------|------|------|-------------|
| GET | `/api/deliveries/available` | ✅ | LIVREUR | Liste des livraisons disponibles |
| GET | `/api/deliveries/active` | ✅ | LIVREUR | Ma livraison active en cours |
| POST | `/api/deliveries/:id/accept` | ✅ | LIVREUR | Accepter une livraison |
| PATCH | `/api/deliveries/:id/status` | ✅ | LIVREUR | Mettre à jour le statut |
| POST | `/api/deliveries/generate` | ✅ | — | Générer une livraison (admin/test) |

**Statuts livraison :** (chronologie)
```
AVAILABLE → ACCEPTED → AT_RESTAURANT → PICKED_UP → DELIVERED
                                                      CANCELLED
```

**Body pour mise à jour statut (`PATCH /:id/status`) :**
```json
{ "status": "AT_RESTAURANT" }
```

**Endpoints d'acceptation :**
```json
// POST /api/deliveries/:id/accept
// (aucun body requis — le driverId est extrait du token JWT)
```

---

### 🩺 Health Check

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| GET | `/api/health` | — | Statut du serveur + timestamp |

---

## Schéma Base de Données

### Modèles Principaux

- **User** — Comptes clients, restaurateurs, admins
- **Restaurant** — Établissements avec horaires, mode rush, options alimentaires
- **MenuItem** — Articles de menu par restaurant
- **Order / CartItem** — Commandes avec statut, suivi GPS
- **Review** — Avis et notes par restaurant
- **Notification** — Notifications in-app
- **GroupOrder / GroupMember** — Commandes groupées avec partage d'addition
- **Delivery** — Livraisons avec suivi de statut

### Enums

- `UserRole`: `CLIENT | RESTAURANT | LIVREUR | ADMIN`
- `OrderStatus`: `PLACED | PREPARING | READY_FOR_PICKUP | COMPLETED | CANCELLED`
- `GroupOrderStatus`: `OPEN | LOCKED | SUBMITTED | COMPLETED | CANCELLED`
- `GroupMemberPaymentStatus`: `DRAFT | READY | PAID`
- `DeliveryStatus`: `AVAILABLE | ACCEPTED | AT_RESTAURANT | PICKED_UP | DELIVERED | CANCELLED`
- `DietaryOption`: `VEGAN | VEGETARIAN | GLUTEN_FREE | HALAL | KETO | DAIRY_FREE`

## Scripts

| Commande | Description |
|----------|-------------|
| `npm run dev` | Développement avec rechargement automatique |
| `npm run build` | Compilation TypeScript → JavaScript |
| `npm start` | Lancement production (depuis dist/) |
| `npm run db:generate` | Générer le client Prisma |
| `npm run db:push` | Pousser le schéma vers la DB |
| `npm run db:migrate` | Créer une migration Prisma |
| `npm run db:seed` | Insérer des données de test |
| `npm run db:studio` | Ouvrir Prisma Studio |
| `npm run lint` | Linting ESLint |
| `npm test` | Tests Jest |
