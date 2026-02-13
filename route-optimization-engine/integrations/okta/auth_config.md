# Okta SSO Integration Configuration
## Route Optimization Engine - Authentication & Authorization

### Overview

The Route Optimization Engine uses Okta as the identity provider (IdP) for Single
Sign-On (SSO) via OpenID Connect (OIDC). This document covers the OIDC configuration,
scopes, claims mapping, user provisioning flow, token validation, and role mapping.

---

### OIDC Configuration

#### Okta Application Settings

| Setting                    | Value                                                              |
|----------------------------|--------------------------------------------------------------------|
| Application Type           | Web Application                                                    |
| Sign-in Method             | OIDC - OpenID Connect                                              |
| Grant Types                | Authorization Code, Refresh Token                                  |
| Sign-in Redirect URI       | `https://{environment}.routeopt.polaris.com/api/auth/callback`     |
| Sign-out Redirect URI      | `https://{environment}.routeopt.polaris.com/logout`                |
| Initiate Login URI         | `https://{environment}.routeopt.polaris.com/login`                 |
| Base URI                   | `https://{environment}.routeopt.polaris.com`                       |
| Controlled Access          | Limit access to selected groups                                    |

#### Environment-Specific Configuration

| Parameter                  | Staging                                              | Production                                         |
|----------------------------|------------------------------------------------------|----------------------------------------------------|
| Okta Domain                | `polaris-staging.okta.com`                           | `polaris.okta.com`                                 |
| Client ID                  | `0oa1234567staging`                                  | `0oa1234567prod`                                   |
| Issuer URI                 | `https://polaris-staging.okta.com/oauth2/default`    | `https://polaris.okta.com/oauth2/default`          |
| Authorization Endpoint     | `{issuer}/v1/authorize`                              | `{issuer}/v1/authorize`                            |
| Token Endpoint             | `{issuer}/v1/token`                                  | `{issuer}/v1/token`                                |
| UserInfo Endpoint          | `{issuer}/v1/userinfo`                               | `{issuer}/v1/userinfo`                             |
| JWKS URI                   | `{issuer}/v1/keys`                                   | `{issuer}/v1/keys`                                 |
| Redirect URI               | `https://staging.routeopt.polaris.com/api/auth/callback` | `https://routeopt.polaris.com/api/auth/callback` |

#### PKCE Configuration

Proof Key for Code Exchange (PKCE) is **required** for all authorization code flows:

| PKCE Setting               | Value                        |
|----------------------------|------------------------------|
| Code Challenge Method      | S256                         |
| Require PKCE               | Yes                          |

---

### Scopes and Claims Mapping

#### Requested Scopes

| Scope              | Purpose                                              | Required |
|--------------------|------------------------------------------------------|----------|
| `openid`           | Core OIDC scope, returns sub claim                    | Yes      |
| `profile`          | User profile (name, preferred_username)               | Yes      |
| `email`            | User email address                                    | Yes      |
| `groups`           | Okta group memberships for role mapping               | Yes      |
| `offline_access`   | Enables refresh token issuance                        | Yes      |

#### Custom Claims (Authorization Server)

The following custom claims are configured on the Okta Authorization Server:

| Claim Name           | Source                              | ID Token | Access Token | Description                               |
|----------------------|--------------------------------------|----------|--------------|-------------------------------------------|
| `sub`                | `user.email`                        | Yes      | Yes          | Subject identifier (user email)            |
| `name`               | `user.displayName`                  | Yes      | No           | Full display name                          |
| `email`              | `user.email`                        | Yes      | Yes          | Email address                              |
| `email_verified`     | `user.emailVerified`                | Yes      | No           | Whether email is verified                  |
| `given_name`         | `user.firstName`                    | Yes      | No           | First name                                 |
| `family_name`        | `user.lastName`                     | Yes      | No           | Last name                                  |
| `groups`             | `getFilteredGroups({"route-opt-"})` | Yes      | Yes          | Groups matching route-opt- prefix          |
| `employee_id`        | `user.employeeNumber`               | No       | Yes          | Internal employee identifier               |
| `zone_access`        | `appuser.zone_access`               | No       | Yes          | Comma-separated zone IDs for data filtering|

#### ID Token Example (decoded payload)

```json
{
  "sub": "jane.doe@polaris.com",
  "name": "Jane Doe",
  "email": "jane.doe@polaris.com",
  "email_verified": true,
  "given_name": "Jane",
  "family_name": "Doe",
  "groups": [
    "route-opt-admin",
    "route-opt-dispatcher"
  ],
  "iss": "https://polaris.okta.com/oauth2/default",
  "aud": "0oa1234567prod",
  "iat": 1706000000,
  "exp": 1706003600
}
```

---

### User Provisioning Flow

#### Provisioning Architecture

```
                          1. User assigned to app
                          +---------------------+
                          |                     |
                          v                     |
+----------+     +---------------+     +------------------+
|  Okta    |---->| SCIM 2.0      |---->| Route Opt API    |
|  Admin   |     | Provisioning  |     | /api/v1/users    |
|  Console |     | Endpoint      |     | (SCIM receiver)  |
+----------+     +---------------+     +------------------+
                          |                     |
                          v                     v
                  +---------------+     +------------------+
                  | Okta User     |     | MongoDB          |
                  | Directory     |     | users collection |
                  +---------------+     +------------------+
```

#### Provisioning Events

| Event                  | Okta Action                           | Application Action                          |
|------------------------|---------------------------------------|---------------------------------------------|
| User assigned to app   | SCIM POST /Users                      | Create user record in MongoDB               |
| User profile updated   | SCIM PUT /Users/{id}                  | Update user record in MongoDB               |
| User deactivated       | SCIM PATCH /Users/{id} active=false   | Deactivate user, revoke sessions            |
| User removed from app  | SCIM DELETE /Users/{id}               | Soft-delete user, revoke sessions           |
| Group membership change| SCIM PATCH /Groups/{id}               | Update user roles in MongoDB                |
| Password change        | N/A (Okta-managed)                    | No action needed (tokens invalidated)       |

#### SCIM 2.0 Configuration

| Setting                         | Value                                                          |
|---------------------------------|----------------------------------------------------------------|
| SCIM Connector Base URL         | `https://{environment}.routeopt.polaris.com/api/scim/v2`       |
| Authentication Mode             | HTTP Header (Bearer token)                                     |
| Unique User Field               | `email`                                                        |
| Supported Provisioning Actions  | Create Users, Update User Attributes, Deactivate Users         |
| Sync Schedule                   | Push groups and users immediately on change                    |

#### User Schema (MongoDB)

```json
{
  "_id": "ObjectId",
  "okta_id": "00u1a2b3c4d5e6f7g8",
  "email": "jane.doe@polaris.com",
  "first_name": "Jane",
  "last_name": "Doe",
  "display_name": "Jane Doe",
  "employee_id": "EMP-12345",
  "roles": ["admin", "dispatcher"],
  "zone_access": ["zone-north", "zone-south"],
  "is_active": true,
  "created_at": "2025-01-15T10:00:00Z",
  "updated_at": "2025-06-01T14:30:00Z",
  "last_login_at": "2025-06-15T08:45:00Z",
  "provisioned_by": "okta_scim"
}
```

---

### Token Validation Flow

#### Authentication Flow Diagram

```
User Browser                API Backend                  Okta
    |                           |                          |
    |  1. GET /login            |                          |
    |-------------------------->|                          |
    |                           |                          |
    |  2. 302 Redirect          |                          |
    |<--------------------------|                          |
    |                           |                          |
    |  3. GET /authorize        |                          |
    |  (with PKCE challenge)    |                          |
    |-------------------------------------------------------->|
    |                           |                          |
    |  4. Okta Login Page       |                          |
    |<---------------------------------------------------------|
    |                           |                          |
    |  5. User enters creds     |                          |
    |-------------------------------------------------------->|
    |                           |                          |
    |  6. (Optional) MFA prompt |                          |
    |<---------------------------------------------------------|
    |                           |                          |
    |  7. MFA verification      |                          |
    |-------------------------------------------------------->|
    |                           |                          |
    |  8. 302 Redirect with     |                          |
    |     authorization code    |                          |
    |<---------------------------------------------------------|
    |                           |                          |
    |  9. GET /callback?code=   |                          |
    |-------------------------->|                          |
    |                           |                          |
    |                           | 10. POST /token          |
    |                           | (code + PKCE verifier)   |
    |                           |------------------------->|
    |                           |                          |
    |                           | 11. ID + Access +        |
    |                           |     Refresh tokens       |
    |                           |<-------------------------|
    |                           |                          |
    |                           | 12. Validate ID token    |
    |                           | (signature, claims,      |
    |                           |  issuer, audience, exp)  |
    |                           |                          |
    |                           | 13. Create session       |
    |                           | (store refresh token)    |
    |                           |                          |
    | 14. Set session cookie    |                          |
    |<--------------------------|                          |
    |                           |                          |
    | 15. GET /api/routes       |                          |
    | (with session cookie)     |                          |
    |-------------------------->|                          |
    |                           |                          |
    |                           | 16. Validate access      |
    |                           | token (local JWKS cache) |
    |                           |                          |
    | 17. API response          |                          |
    |<--------------------------|                          |
```

#### Token Validation Steps (Backend Middleware)

For every authenticated API request, the backend performs the following validation:

1. **Extract token**: Read the access token from the `Authorization: Bearer <token>` header or session cookie.

2. **Verify signature**: Validate the JWT signature using the public keys fetched from the Okta JWKS endpoint. Keys are cached locally with a 24-hour TTL.

3. **Validate issuer**: Confirm `iss` claim matches the expected Okta issuer URI.

4. **Validate audience**: Confirm `aud` claim matches the application's client ID.

5. **Check expiration**: Verify `exp` claim has not passed. Reject if expired.

6. **Check not-before**: Verify `nbf` claim (if present) has passed.

7. **Validate subject**: Confirm `sub` claim corresponds to an active user in the local database.

8. **Extract roles**: Parse the `groups` claim and map to application roles (see Role Mapping below).

9. **Attach context**: Attach the validated user context (user ID, roles, zone access) to the request for downstream authorization checks.

#### Token Lifetimes

| Token Type      | Lifetime        | Refresh Strategy                               |
|-----------------|-----------------|------------------------------------------------|
| ID Token        | 1 hour          | Re-issued with refresh token flow              |
| Access Token    | 1 hour          | Refreshed automatically when < 5 min remaining |
| Refresh Token   | 7 days (idle)   | Rotated on each use; revoked on logout         |
| Session Cookie  | 8 hours         | Sliding expiration, renewed on activity        |

---

### Role Mapping: Okta Groups to Application Roles

#### Group-to-Role Mapping Table

| Okta Group Name              | Application Role    | Description                                      | Permissions                                                         |
|------------------------------|---------------------|--------------------------------------------------|---------------------------------------------------------------------|
| `route-opt-admin`            | `admin`             | Full system administrators                       | All permissions, user management, system configuration              |
| `route-opt-dispatcher`       | `dispatcher`        | Route dispatchers and planners                   | Create/edit/approve routes, manage work orders, view all zones      |
| `route-opt-supervisor`       | `supervisor`        | Field service supervisors                        | View routes, manage technicians in assigned zones, approve changes  |
| `route-opt-technician`       | `technician`        | Field service technicians                        | View own routes, update work order status, view assigned properties |
| `route-opt-analyst`          | `analyst`           | Data analysts and report consumers               | Read-only access to all data, Looker dashboard access               |
| `route-opt-viewer`           | `viewer`            | Stakeholders with view-only access               | Read-only access to dashboards and summary reports                  |

#### Permission Matrix

| Permission                        | admin | dispatcher | supervisor | technician | analyst | viewer |
|-----------------------------------|-------|------------|------------|------------|---------|--------|
| View all routes                   | Yes   | Yes        | Zone only  | Own only   | Yes     | Yes    |
| Create routes                     | Yes   | Yes        | No         | No         | No      | No     |
| Edit routes                       | Yes   | Yes        | No         | No         | No      | No     |
| Delete routes                     | Yes   | No         | No         | No         | No      | No     |
| Run optimization                  | Yes   | Yes        | No         | No         | No      | No     |
| Approve optimized routes          | Yes   | Yes        | Zone only  | No         | No      | No     |
| Manage work orders                | Yes   | Yes        | Zone only  | Own only   | No      | No     |
| Update work order status          | Yes   | Yes        | Zone only  | Own only   | No      | No     |
| View technician details           | Yes   | Yes        | Zone only  | Own only   | Yes     | No     |
| Manage technician profiles        | Yes   | Yes        | Zone only  | No         | No      | No     |
| View properties                   | Yes   | Yes        | Zone only  | Assigned   | Yes     | Yes    |
| Access Looker dashboards          | Yes   | Yes        | Yes        | Limited    | Yes     | Yes    |
| Export data                       | Yes   | Yes        | No         | No         | Yes     | No     |
| Manage users                      | Yes   | No         | No         | No         | No      | No     |
| System configuration              | Yes   | No         | No         | No         | No      | No     |
| View audit logs                   | Yes   | No         | No         | No         | Yes     | No     |

#### Role Resolution Logic

When a user belongs to multiple Okta groups, the most permissive role applies:

```
admin > dispatcher > supervisor > analyst > technician > viewer
```

The backend resolves the effective role as follows:

```python
ROLE_HIERARCHY = {
    "admin": 100,
    "dispatcher": 80,
    "supervisor": 60,
    "analyst": 40,
    "technician": 20,
    "viewer": 10,
}

def resolve_effective_role(okta_groups: list[str]) -> str:
    """Determine the highest-priority role from Okta group memberships."""
    roles = []
    for group in okta_groups:
        # Strip the "route-opt-" prefix to get the role name
        if group.startswith("route-opt-"):
            role = group.replace("route-opt-", "")
            if role in ROLE_HIERARCHY:
                roles.append(role)

    if not roles:
        return "viewer"  # Default to minimum access

    return max(roles, key=lambda r: ROLE_HIERARCHY.get(r, 0))
```

#### Zone-Based Access Control

In addition to role-based permissions, data access is filtered by geographic zone:

- The `zone_access` custom claim (or user profile attribute) contains the zones a user can access.
- Dispatchers and admins have access to all zones by default.
- Supervisors and technicians are restricted to their assigned zones.
- Zone filtering is applied at the database query level and Looker access filter level.

```python
def get_accessible_zones(user_context: dict) -> list[str]:
    """Return the list of zones the user can access."""
    if user_context["role"] in ("admin", "dispatcher", "analyst"):
        return ["*"]  # All zones
    return user_context.get("zone_access", [])
```
