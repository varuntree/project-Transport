# Phase 3: User Features (Auth + Favorites)
**Duration:** 2-3 weeks | **Timeline:** Week 9-11
**Goal:** Apple Sign-In, favorites CRUD, cross-device sync

---

## Overview
- Supabase Auth integration (Apple Sign-In)
- Protected API endpoints (`/favorites`)
- RLS policies (user data isolation)
- iOS auth flow (Keychain token storage)
- Favorites UI (add, delete, sync)

---

## User Instructions

### 1. Enable Supabase Auth
1. Supabase Dashboard → Authentication → Providers
2. Enable "Apple" provider
3. Apple Developer Portal:
   - Create Service ID (Identifier: `com.sydneytransit.auth`)
   - Enable Sign in with Apple
   - Configure Return URLs: `https://YOUR_PROJECT.supabase.co/auth/v1/callback`
4. Copy Keys:
   - Service ID
   - Team ID
   - Key ID
   - Private Key (.p8 file)
5. Paste into Supabase Apple provider config

### 2. Configure iOS Entitlements
Xcode → Signing & Capabilities → "+ Capability" → Sign in with Apple

---

## Implementation Checklist

### Backend

**1. Favorites Schema (migration 002_favorites.sql)**
```sql
CREATE TABLE favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    stop_id TEXT NOT NULL REFERENCES stops(stop_id),
    nickname TEXT,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, stop_id)
);

CREATE INDEX idx_favorites_user ON favorites(user_id);

-- RLS Policies
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own favorites"
    ON favorites FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own favorites"
    ON favorites FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own favorites"
    ON favorites FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own favorites"
    ON favorites FOR DELETE
    USING (auth.uid() = user_id);
```

**2. Auth Dependency (app/dependencies.py)**
```python
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi import Depends, HTTPException
from app.db.supabase_client import get_supabase

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    supabase = Depends(get_supabase)
):
    """Verify Supabase JWT, return user."""
    token = credentials.credentials
    try:
        user = supabase.auth.get_user(token)
        return user.user
    except Exception:
        raise HTTPException(status_code=401, detail={"code": "INVALID_TOKEN"})
```

**3. Favorites API (app/api/v1/favorites.py)**
```python
from fastapi import APIRouter, Depends
from app.dependencies import get_current_user

router = APIRouter()

@router.get("/favorites")
async def list_favorites(user = Depends(get_current_user), supabase = Depends(get_supabase)):
    result = supabase.table('favorites').select('*, stops(*)').eq('user_id', user.id).order('display_order').execute()
    return SuccessResponse(data=result.data)

@router.post("/favorites")
async def create_favorite(
    favorite: FavoriteCreate,
    user = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    data = {'user_id': user.id, 'stop_id': favorite.stop_id, 'nickname': favorite.nickname}
    result = supabase.table('favorites').insert(data).execute()
    return SuccessResponse(data=result.data[0])

@router.delete("/favorites/{favorite_id}")
async def delete_favorite(
    favorite_id: str,
    user = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    supabase.table('favorites').delete().eq('id', favorite_id).eq('user_id', user.id).execute()
    return SuccessResponse(data={'deleted': favorite_id})
```

---

### iOS

**4. Auth Manager (Core/Auth/SupabaseAuthManager.swift)**
```swift
import Supabase
import AuthenticationServices

class SupabaseAuthManager: ObservableObject {
    static let shared = SupabaseAuthManager()
    private let supabase: SupabaseClient
    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private init() {
        supabase = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
        checkSession()
    }

    func signInWithApple() async throws {
        let session = try await supabase.auth.signInWithApple()
        currentUser = session.user
        isAuthenticated = true
        saveToken(session.accessToken)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        currentUser = nil
        isAuthenticated = false
        clearToken()
    }

    private func saveToken(_ token: String) {
        // Keychain storage (see DEVELOPMENT_STANDARDS.md)
        KeychainHelper.save(token, forKey: "supabase_token")
    }

    private func clearToken() {
        KeychainHelper.delete(forKey: "supabase_token")
    }

    private func checkSession() {
        if let token = KeychainHelper.load(forKey: "supabase_token") {
            Task {
                do {
                    let user = try await supabase.auth.getUser(jwt: token)
                    await MainActor.run {
                        self.currentUser = user
                        self.isAuthenticated = true
                    }
                } catch {
                    clearToken()
                }
            }
        }
    }
}
```

**5. Favorites Repository (Data/Repositories/FavoritesRepository.swift)**
```swift
protocol FavoritesRepository {
    func fetchFavorites() async throws -> [Favorite]
    func addFavorite(stopId: String, nickname: String?) async throws -> Favorite
    func deleteFavorite(id: String) async throws
}

class FavoritesRepositoryImpl: FavoritesRepository {
    private let apiClient: APIClient

    func fetchFavorites() async throws -> [Favorite] {
        let endpoint = APIEndpoint.getFavorites
        let response: SuccessResponse<[Favorite]> = try await apiClient.request(endpoint)
        return response.data
    }

    func addFavorite(stopId: String, nickname: String?) async throws -> Favorite {
        let endpoint = APIEndpoint.createFavorite(stopId: stopId, nickname: nickname)
        let response: SuccessResponse<Favorite> = try await apiClient.request(endpoint)
        return response.data
    }

    func deleteFavorite(id: String) async throws {
        let endpoint = APIEndpoint.deleteFavorite(id: id)
        let _: SuccessResponse<[String: String]> = try await apiClient.request(endpoint)
    }
}
```

**6. Sign-In View (Features/Auth/SignInView.swift)**
```swift
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Sydney Transit")
                .font(.largeTitle)
            Text("Sign in to save favorites")
                .foregroundColor(.secondary)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email]
            } onCompletion: { result in
                Task {
                    do {
                        try await authManager.signInWithApple()
                    } catch {
                        Logger.app.error("Sign in failed: \(error)")
                    }
                }
            }
            .frame(height: 50)
            .padding()
        }
    }
}
```

**7. Favorites View (Features/Favorites/FavoritesView.swift)**
```swift
struct FavoritesView: View {
    @StateObject private var viewModel: FavoritesViewModel

    var body: some View {
        List {
            ForEach(viewModel.favorites) { favorite in
                NavigationLink(value: favorite) {
                    VStack(alignment: .leading) {
                        Text(favorite.stop.name)
                            .font(.headline)
                        if let nickname = favorite.nickname {
                            Text(nickname)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await viewModel.deleteFavorite(viewModel.favorites[index])
                    }
                }
            }
        }
        .navigationTitle("Favorites")
        .toolbar {
            NavigationLink("Add") {
                AddFavoriteView()
            }
        }
        .onAppear {
            Task { await viewModel.loadFavorites() }
        }
    }
}
```

---

## Acceptance Criteria

**Backend:**
- [ ] `/favorites` requires auth (401 without token)
- [ ] User A cannot see User B's favorites (RLS enforced)
- [ ] Create/delete favorites work

**iOS:**
- [ ] Sign in with Apple works (token saved to Keychain)
- [ ] Favorites sync across devices
- [ ] Sign out clears token

---

## Next Phase: Trip Planning (Week 12-13)

**End of PHASE_3_USER_FEATURES.md**
