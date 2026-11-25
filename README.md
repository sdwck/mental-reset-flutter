# Mental Reset — PAM labs

- `mental_reset/` — Flutter app (L4: Provider + Repository with mock, L5: HTTP repository + JWT)
- `backend/` — ASP.NET Core Minimal API (L5): JWT, SQLite, notes + sessions CRUD, files
- `reports/` — lab reports (PDF) and defense notes

Run backend: `cd backend/src && dotnet run --urls http://localhost:5080`, contract tests: `bash backend/tests/contract.sh`.
Run app: `cd mental_reset && flutter run -d chrome`.
