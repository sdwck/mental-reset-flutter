// Mental Reset API — учебный backend для PAM L5.
// Контракт: JWT-аутентификация, пагинированный CRUD notes (база шаблона)
// и sessions (сущность темы), загрузка файлов multipart.
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Лабораторная конфигурация: секрет по умолчанию, открытый CORS. Не для production.
var jwtKey = builder.Configuration["Jwt:Key"] ?? "pam-lab-dev-secret-key-change-me-0123456789";
var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));

builder.Services.AddDbContext<AppDb>(o =>
    o.UseSqlite(builder.Configuration.GetConnectionString("Db") ?? "Data Source=mental_reset.db"));
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o => o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = false,
        ValidateAudience = false,
        IssuerSigningKey = signingKey,
        ClockSkew = TimeSpan.FromSeconds(30),
    });
builder.Services.AddAuthorization();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDb>();
    db.Database.EnsureCreated();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

// ---------- Auth ----------
app.MapPost("/auth/register", async (Credentials c, AppDb db) =>
{
    if (string.IsNullOrWhiteSpace(c.Email) || !c.Email.Contains('@') || (c.Password?.Length ?? 0) < 6)
        return Results.BadRequest(new ErrorBody("email must contain @, password at least 6 chars"));
    if (await db.Users.AnyAsync(u => u.Email == c.Email))
        return Results.Conflict(new ErrorBody("email already registered"));
    var user = new User { Email = c.Email.Trim().ToLowerInvariant(), PasswordHash = Hash(c.Password!) };
    db.Users.Add(user);
    await db.SaveChangesAsync();
    return Results.Created($"/auth/me", new TokenBody(IssueToken(user)));
});

app.MapPost("/auth/login", async (Credentials c, AppDb db) =>
{
    var email = c.Email?.Trim().ToLowerInvariant();
    var user = await db.Users.FirstOrDefaultAsync(u => u.Email == email);
    if (user is null || user.PasswordHash != Hash(c.Password ?? ""))
        return Results.Json(new ErrorBody("invalid email or password"), statusCode: 401);
    return Results.Ok(new TokenBody(IssueToken(user)));
});

app.MapGet("/auth/me", (ClaimsPrincipal p) => Results.Ok(new { id = Me.Id(p), email = p.FindFirstValue(ClaimTypes.Email) }))
    .RequireAuthorization();

// ---------- Notes (база шаблона) ----------
var notes = app.MapGroup("/notes").RequireAuthorization();
notes.MapGet("/", async (ClaimsPrincipal p, AppDb db, int page = 1, int pageSize = 20, string? q = null) =>
{
    var query = db.Notes.Where(n => n.UserId == Me.Id(p));
    if (!string.IsNullOrWhiteSpace(q)) query = query.Where(n => n.Title.Contains(q) || n.Body.Contains(q));
    return Results.Ok(await Paginate(query.OrderByDescending(n => n.Id), page, pageSize));
});
notes.MapGet("/{id:int}", async (int id, ClaimsPrincipal p, AppDb db) =>
    await db.Notes.FirstOrDefaultAsync(n => n.Id == id && n.UserId == Me.Id(p)) is { } n
        ? Results.Ok(n) : Results.NotFound(new ErrorBody($"note {id} not found")));
notes.MapPost("/", async (NoteInput input, ClaimsPrincipal p, AppDb db) =>
{
    if (string.IsNullOrWhiteSpace(input.Title)) return Results.BadRequest(new ErrorBody("title is required"));
    var n = new Note { Title = input.Title.Trim(), Body = input.Body ?? "", UserId = Me.Id(p) };
    db.Notes.Add(n);
    await db.SaveChangesAsync();
    return Results.Created($"/notes/{n.Id}", n);
});
notes.MapPut("/{id:int}", async (int id, NoteInput input, ClaimsPrincipal p, AppDb db) =>
{
    var n = await db.Notes.FirstOrDefaultAsync(x => x.Id == id && x.UserId == Me.Id(p));
    if (n is null) return Results.NotFound(new ErrorBody($"note {id} not found"));
    if (string.IsNullOrWhiteSpace(input.Title)) return Results.BadRequest(new ErrorBody("title is required"));
    n.Title = input.Title.Trim();
    n.Body = input.Body ?? "";
    await db.SaveChangesAsync();
    return Results.Ok(n);
});
notes.MapDelete("/{id:int}", async (int id, ClaimsPrincipal p, AppDb db) =>
{
    var n = await db.Notes.FirstOrDefaultAsync(x => x.Id == id && x.UserId == Me.Id(p));
    if (n is null) return Results.NotFound(new ErrorBody($"note {id} not found"));
    db.Notes.Remove(n);
    await db.SaveChangesAsync();
    return Results.NoContent();
});

// ---------- Sessions (сущность темы Mental Reset) ----------
var sessions = app.MapGroup("/sessions").RequireAuthorization();
sessions.MapGet("/", async (ClaimsPrincipal p, AppDb db, int page = 1, int pageSize = 20, string? q = null) =>
{
    var query = db.Sessions.Where(s => s.UserId == Me.Id(p));
    if (!string.IsNullOrWhiteSpace(q)) query = query.Where(s => s.Title.Contains(q) || s.Notes.Contains(q));
    return Results.Ok(await Paginate(query.OrderByDescending(s => s.CreatedAt), page, pageSize));
});
sessions.MapGet("/{id:int}", async (int id, ClaimsPrincipal p, AppDb db) =>
    await db.Sessions.FirstOrDefaultAsync(s => s.Id == id && s.UserId == Me.Id(p)) is { } s
        ? Results.Ok(s) : Results.NotFound(new ErrorBody($"session {id} not found")));
sessions.MapPost("/", async (SessionInput input, ClaimsPrincipal p, AppDb db) =>
{
    if (Validate(input) is { } err) return Results.BadRequest(new ErrorBody(err));
    var s = new MindfulSession { UserId = Me.Id(p), CreatedAt = DateTime.UtcNow };
    Apply(s, input);
    db.Sessions.Add(s);
    await db.SaveChangesAsync();
    return Results.Created($"/sessions/{s.Id}", s);
});
sessions.MapPut("/{id:int}", async (int id, SessionInput input, ClaimsPrincipal p, AppDb db) =>
{
    var s = await db.Sessions.FirstOrDefaultAsync(x => x.Id == id && x.UserId == Me.Id(p));
    if (s is null) return Results.NotFound(new ErrorBody($"session {id} not found"));
    if (Validate(input) is { } err) return Results.BadRequest(new ErrorBody(err));
    Apply(s, input);
    await db.SaveChangesAsync();
    return Results.Ok(s);
});
sessions.MapDelete("/{id:int}", async (int id, ClaimsPrincipal p, AppDb db) =>
{
    var s = await db.Sessions.FirstOrDefaultAsync(x => x.Id == id && x.UserId == Me.Id(p));
    if (s is null) return Results.NotFound(new ErrorBody($"session {id} not found"));
    db.Sessions.Remove(s);
    await db.SaveChangesAsync();
    return Results.NoContent();
});

// ---------- Files (multipart) ----------
var uploads = Path.Combine(app.Environment.ContentRootPath, "uploads");
Directory.CreateDirectory(uploads);
app.MapPost("/files", async (IFormFile file, ClaimsPrincipal p, AppDb db) =>
{
    if (file.Length == 0 || file.Length > 5 * 1024 * 1024)
        return Results.BadRequest(new ErrorBody("file must be 1 byte .. 5 MB"));
    var stored = new StoredFile { UserId = Me.Id(p), FileName = Path.GetFileName(file.FileName), ContentType = file.ContentType, Size = file.Length };
    db.Files.Add(stored);
    await db.SaveChangesAsync();
    await using var fs = File.Create(Path.Combine(uploads, stored.Id.ToString()));
    await file.CopyToAsync(fs);
    return Results.Created($"/files/{stored.Id}", new { stored.Id, stored.FileName, stored.Size, url = $"/files/{stored.Id}" });
}).RequireAuthorization().DisableAntiforgery();
app.MapGet("/files/{id:int}", async (int id, AppDb db) =>
    await db.Files.FindAsync(id) is { } f
        ? Results.File(Path.Combine(uploads, id.ToString()), f.ContentType, f.FileName)
        : Results.NotFound(new ErrorBody($"file {id} not found")));

app.Run();

// ---------- helpers ----------
string IssueToken(User u)
{
    var token = new JwtSecurityToken(
        claims: [new Claim(ClaimTypes.NameIdentifier, u.Id.ToString()), new Claim(ClaimTypes.Email, u.Email)],
        expires: DateTime.UtcNow.AddDays(7),
        signingCredentials: new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256));
    return new JwtSecurityTokenHandler().WriteToken(token);
}


static string Hash(string password) =>
    Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes("pam-salt:" + password)));

static async Task<PageResult<T>> Paginate<T>(IQueryable<T> q, int page, int pageSize)
{
    page = Math.Max(1, page);
    pageSize = Math.Clamp(pageSize, 1, 100);
    var total = await q.CountAsync();
    var items = await q.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();
    return new PageResult<T>(items, page, pageSize, total);
}

static string? Validate(SessionInput i) =>
    string.IsNullOrWhiteSpace(i.Title) || i.Title.Trim().Length < 3 ? "title must be at least 3 chars"
    : i.PracticeType is not ("breathe" or "meditation" or "timer" or "canvas") ? "unknown practiceType"
    : i.DurationMin is < 1 or > 120 ? "durationMin must be 1..120"
    : null;

static void Apply(MindfulSession s, SessionInput i)
{
    s.Title = i.Title!.Trim();
    s.PracticeType = i.PracticeType!;
    s.DurationMin = i.DurationMin;
    s.Notes = i.Notes ?? "";
    s.SoundEnabled = i.SoundEnabled;
}

// ---------- types ----------
record Credentials(string? Email, string? Password);
record TokenBody(string Token);
record ErrorBody(string Error);
record NoteInput(string? Title, string? Body);
record SessionInput(string? Title, string? PracticeType, int DurationMin, string? Notes, bool SoundEnabled);
record PageResult<T>(List<T> Items, int Page, int PageSize, int Total);

class User { public int Id { get; set; } public string Email { get; set; } = ""; public string PasswordHash { get; set; } = ""; }
class Note { public int Id { get; set; } public int UserId { get; set; } public string Title { get; set; } = ""; public string Body { get; set; } = ""; }
class MindfulSession
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string Title { get; set; } = "";
    public string PracticeType { get; set; } = "";
    public int DurationMin { get; set; }
    public string Notes { get; set; } = "";
    public bool SoundEnabled { get; set; }
    public DateTime CreatedAt { get; set; }
}
class StoredFile { public int Id { get; set; } public int UserId { get; set; } public string FileName { get; set; } = ""; public string ContentType { get; set; } = ""; public long Size { get; set; } }

class AppDb(DbContextOptions<AppDb> o) : DbContext(o)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Note> Notes => Set<Note>();
    public DbSet<MindfulSession> Sessions => Set<MindfulSession>();
    public DbSet<StoredFile> Files => Set<StoredFile>();
}

static class Me
{
    public static int Id(ClaimsPrincipal p) => int.Parse(p.FindFirstValue(ClaimTypes.NameIdentifier)!);
}

public partial class Program;
