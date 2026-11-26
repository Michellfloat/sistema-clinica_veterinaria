$ErrorActionPreference = "Stop"

$BaseDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
Set-Location $BaseDir

# Garante que a pasta database existe
$DbDir = Join-Path $BaseDir "database"
if (-not (Test-Path $DbDir)) {
    New-Item -ItemType Directory -Force -Path $DbDir | Out-Null
}

# Detecta o comando do Python no Windows
$PythonCmd = if (Get-Command python -ErrorAction SilentlyContinue) { "python" }
             elseif (Get-Command py -ErrorAction SilentlyContinue) { "py" }
             else { throw "Python não encontrado no PATH. Instale o Python 3 antes de continuar." }

Write-Host "Instalando dependências Python (cryptography, bcrypt)..." -ForegroundColor Cyan
& $PythonCmd -m pip install cryptography bcrypt -q

$PyScript = @'
import os, base64, hashlib, hmac, bcrypt
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

AES_SECRET = "clinica-veterinaria-chave-aes-cpf-dev"
HMAC_SECRET = "clinica-veterinaria-chave-hmac-cpf-dev"
key_aes = hashlib.sha256(AES_SECRET.encode()).digest()
key_hmac = hashlib.sha256(HMAC_SECRET.encode()).digest()

def cifrar(t):
    iv = os.urandom(12)
    return base64.b64encode(iv + AESGCM(key_aes).encrypt(iv, t.encode(), None)).decode()

def h(t):
    return hmac.new(key_hmac, t.encode(), hashlib.sha256).hexdigest()

def bc(p):
    return bcrypt.hashpw(p.encode(), bcrypt.gensalt(10, b"2a")).decode()

def q(s):
    return "NULL" if s is None else "'" + str(s).replace("'", "''") + "'"

schema = open("backend/src/main/resources/db/migration/V1__criar_schema.sql", encoding="utf8").read()
schema = schema.split("-- Perfis (roles) fixos")[0]

tutores = [
    ("Mariana Souza", "52998224725", "(71) 99811-2233", "mariana.souza@email.com", "Rua das Acácias, 120 - Pituba, Salvador/BA"),
    ("Carlos Eduardo Lima", "11144477735", "(71) 98822-4455", "carlos.lima@email.com", "Av. Oceânica, 900 - Barra, Salvador/BA"),
    ("Fernanda Oliveira", "93541134780", "(71) 99700-1010", "fernanda.o@email.com", "Rua da Paz, 45 - Rio Vermelho, Salvador/BA")
]
usuarios = [
    ("Administrador Geral", "admin@clinicavet.com", "Admin@123", 1, None),
    ("Ana Atendente", "atendente@clinicavet.com", "Atend@123", 2, None),
    ("Mariana Souza", "tutor@clinicavet.com", "Tutor@123", 3, 1),
    ("Thor (Pet)", "pet@clinicavet.com", "Pet@1234", 4, 1)
]
pets = [
    ("Thor", "Cão", "Golden Retriever", "2020-03-14", 1),
    ("Mel", "Gato", "Siamês", "2021-07-02", 2),
    ("Bob", "Cão", "Vira-lata", "2019-11-20", 3),
    ("Luna", "Gato", "Persa", "2022-01-09", 1)
]
ags = [
    ("2026-12-01 09:00:00", "Vacina antirrábica", "Trazer carteirinha", "AGENDADO", 1, 2),
    ("2026-12-01 14:30:00", "Consulta de rotina", None, "CONFIRMADO", 2, 2),
    ("2026-12-03 10:00:00", "Retorno pós-cirúrgico", "Jejum de 8h", "AGENDADO", 3, 2),
    ("2026-12-06 16:00:00", "Banho e tosa", None, "AGENDADO", 1, 1)
]

o = [
    "-- ============================================================",
    "-- saep_db.sql - Banco de dados da Clínica Veterinária (MySQL 8+)",
    "-- Cria o banco, as tabelas e popula com >= 3 registros por tabela.",
    "-- Senhas (BCrypt): admin@clinicavet.com / Admin@123 | atendente@clinicavet.com / Atend@123",
    "--                  tutor@clinicavet.com / Tutor@123 | pet@clinicavet.com / Pet@1234",
    "-- CPF: cifrado com AES-256-GCM + HMAC-SHA256 (chaves de DEV do application.properties).",
    "-- Ao usar este script, a API sobe sem recriar o schema (Flyway baseline na V1).",
    "-- ============================================================",
    "DROP DATABASE IF EXISTS saep_db;",
    "CREATE DATABASE saep_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;",
    "USE saep_db;", "SET NAMES utf8mb4;", "", schema, "",
    "-- ===== DADOS =====",
    "INSERT INTO perfil (id, nome, descricao) VALUES",
    " (1,'ADMIN','Administrador: acesso total, usuários e logs'),",
    " (2,'USUARIO','Usuário comum (atendente): gerencia tutores, pets e agendamentos'),",
    " (3,'TUTOR','Tutor: consulta os pets e agendamentos vinculados a ele'),",
    " (4,'PET','Pet: acesso somente leitura aos próprios agendamentos');", "",
    "INSERT INTO tutor (id, nome, cpf_criptografado, cpf_hash, telefone, email, endereco) VALUES"
]
o.append(",\n".join(f" ({i+1},{q(n)},{q(cifrar(c))},{q(h(c))},{q(t)},{q(e)},{q(en)})" for i, (n, c, t, e, en) in enumerate(tutores)) + ";\n")
o.append("INSERT INTO usuario (id, nome, email, senha, foto_url, ativo, perfil_id, tutor_id) VALUES")
o.append(",\n".join(f" ({i+1},{q(n)},{q(e)},{q(bc(p))},NULL,TRUE,{pf},{q(tu) if tu else 'NULL'})".replace("'1'", "1") for i, (n, e, p, pf, tu) in enumerate(usuarios)) + ";\n")
o.append("INSERT INTO pet (id, nome, especie, raca, data_nascimento, tutor_id) VALUES")
o.append(",\n".join(f" ({i+1},{q(n)},{q(es)},{q(r)},{q(d)},{tu})" for i, (n, es, r, d, tu) in enumerate(pets)) + ";\n")
o.append("INSERT INTO agendamento (id, data_hora, motivo, observacoes, status, pet_id, usuario_id) VALUES")
o.append(",\n".join(f" ({i+1},{q(d)},{q(m)},{q(ob)},{q(s)},{p},{u})" for i, (d, m, ob, s, p, u) in enumerate(ags)) + ";\n")

adm = "admin@clinicavet.com"
at = "atendente@clinicavet.com"

o.append("INSERT INTO log_tutor (tutor_id, acao, descricao, usuario_email, data_hora) VALUES")
o.append(",\n".join(f" ({i+1},'CRIACAO',{q('Tutor cadastrado: '+t[0])},{q(at)},'2026-11-20 08:{10+i}:00')" for i, t in enumerate(tutores)) + ",\n (1,'ATUALIZACAO','Alterado: telefone ''(71) 99999-0000'' -> ''(71) 99811-2233''','" + at + "','2026-11-22 10:05:00');\n")

o.append("INSERT INTO log_pet (pet_id, acao, descricao, usuario_email, data_hora) VALUES")
o.append(",\n".join(f" ({i+1},'CRIACAO',{q('Pet cadastrado: '+p[0])},{q(at)},'2026-11-20 09:{10+i}:00')" for i, p in enumerate(pets)) + ";\n")

o.append("INSERT INTO log_agendamento (agendamento_id, acao, descricao, data_anterior, data_nova, usuario_email, data_hora) VALUES")
rows = [f" ({i+1},'CRIACAO',{q('Agendamento criado para o pet #'+str(a[4])+' em '+a[0][:16])},NULL,{q(a[0])},{q(at)},'2026-11-21 11:{10+i}:00')" for i, a in enumerate(ags)]
rows.append(" (1,'REAGENDAMENTO','Data alterada de 30/11/2026 09:00 para 01/12/2026 09:00','2026-11-30 09:00:00','2026-12-01 09:00:00','" + at + "','2026-11-23 15:40:00')")
o.append(",\n".join(rows) + ";\n")

o.append("INSERT INTO log_usuario (usuario_id, acao, descricao, usuario_email, data_hora) VALUES")
o.append(",\n".join(f" ({i+1},'CRIACAO',{q('Usuário criado: '+u[1])},{q(adm)},'2026-11-19 18:0{i}:00')" for i, u in enumerate(usuarios)) + ",\n (1,'LOGIN','Login realizado com sucesso','" + adm + "','2026-11-25 08:00:00');\n")

with open("database/saep_db.sql", "w", encoding="utf8", newline="\n") as f:
    f.write("\n".join(o))
print("database/saep_db.sql gerado com sucesso!")
'@

$TempPy = Join-Path $env:TEMP "gen_sql.py"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($TempPy, $PyScript.Replace("`r`n", "`n"), $Utf8NoBom)

Write-Host "Gerando database/saep_db.sql..." -ForegroundColor Cyan
& $PythonCmd $TempPy
Remove-Item -Path $TempPy -Force

Write-Host "`nPrévia dos usuários gerados:" -ForegroundColor Green
Select-String -Path "database\saep_db.sql" -Pattern "INSERT INTO usuario" -Context 0, 4 | ForEach-Object {
    $_.Line
    $_.Context.PostContext | ForEach-Object { $_.Substring(0, [Math]::Min(120, $_.Length)) }
}