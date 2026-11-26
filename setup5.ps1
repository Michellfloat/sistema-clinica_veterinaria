$ErrorActionPreference = "Stop"

$BaseDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$TestDir = Join-Path $BaseDir "backend\src\test\java\br\com\clinicavet"

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content.Replace("`r`n", "`n"), $utf8NoBom)
}

# ---- Testes Unitários ----

Write-Utf8NoBom "$TestDir\util\CpfUtilTest.java" @'
package br.com.clinicavet.util;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class CpfUtilTest {

    @Test
    void cpfValido_aceitaComEsemMascara() {
        assertTrue(CpfUtil.valido("529.982.247-25"));
        assertTrue(CpfUtil.valido("52998224725"));
    }

    @Test
    void cpfInvalido_rejeitaDigitosErradosESequencias() {
        assertFalse(CpfUtil.valido("123.456.789-00"));
        assertFalse(CpfUtil.valido("111.111.111-11"));
        assertFalse(CpfUtil.valido("123"));
        assertFalse(CpfUtil.valido(null));
    }

    @Test
    void mascarar_escondeDigitosSensiveis() {
        assertEquals("***.982.247-**", CpfUtil.mascarar("529.982.247-25"));
    }
}
'@

Write-Utf8NoBom "$TestDir\service\CryptoServiceTest.java" @'
package br.com.clinicavet.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class CryptoServiceTest {

    private final CryptoService crypto = new CryptoService("segredo-aes-teste", "segredo-hmac-teste");

    @Test
    void cifrarEDecifrar_devolveOValorOriginal() {
        String cifrado = crypto.cifrar("52998224725");
        assertNotEquals("52998224725", cifrado);
        assertEquals("52998224725", crypto.decifrar(cifrado));
    }

    @Test
    void cifrar_usaIvAleatorio_mesmoTextoGeraCifradosDiferentes() {
        assertNotEquals(crypto.cifrar("52998224725"), crypto.cifrar("52998224725"));
    }

    @Test
    void hash_eDeterministicoCom64Caracteres() {
        assertEquals(crypto.hash("52998224725"), crypto.hash("52998224725"));
        assertEquals(64, crypto.hash("52998224725").length());
        assertNotEquals(crypto.hash("52998224725"), crypto.hash("11144477735"));
    }

    @Test
    void decifrar_comTextoAdulterado_lancaExcecao() {
        String cifrado = crypto.cifrar("52998224725");
        String adulterado = cifrado.substring(0, cifrado.length() - 4) + "AAAA";
        assertThrows(IllegalStateException.class, () -> crypto.decifrar(adulterado));
    }
}
'@

Write-Utf8NoBom "$TestDir\service\TutorServiceTest.java" @'
package br.com.clinicavet.service;

import br.com.clinicavet.dto.TutorRequest;
import br.com.clinicavet.dto.TutorResponse;
import br.com.clinicavet.exception.BusinessException;
import br.com.clinicavet.exception.ConflictException;
import br.com.clinicavet.mapper.TutorMapper;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.repository.PetRepository;
import br.com.clinicavet.repository.TutorRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TutorServiceTest {

    @Mock TutorRepository tutorRepository;
    @Mock PetRepository petRepository;
    @Mock LogService logService;

    private final CryptoService crypto = new CryptoService("segredo-aes-teste", "segredo-hmac-teste");
    private TutorService service;

    @BeforeEach
    void setUp() {
        service = new TutorService(tutorRepository, petRepository, crypto, new TutorMapper(crypto), logService);
    }

    private TutorRequest request(String cpf) {
        return new TutorRequest("Mariana Souza", cpf, "(71) 99811-2233", "mariana@email.com", "Salvador/BA");
    }

    @Test
    void criar_comCpfInvalido_lancaBusinessException() {
        assertThrows(BusinessException.class, () -> service.criar(request("123.456.789-00")));
        verify(tutorRepository, never()).save(any());
    }

    @Test
    void criar_comCpfDuplicado_lancaConflictException() {
        when(tutorRepository.existsByCpfHash(anyString())).thenReturn(true);
        assertThrows(ConflictException.class, () -> service.criar(request("529.982.247-25")));
        verify(tutorRepository, never()).save(any());
    }

    @Test
    void criar_comSucesso_criptografaCpfEMascaraNaResposta() {
        when(tutorRepository.existsByCpfHash(anyString())).thenReturn(false);
        when(tutorRepository.save(any(Tutor.class))).thenAnswer(inv -> {
            Tutor t = inv.getArgument(0);
            t.setId(1L);
            return t;
        });
        when(petRepository.countByTutorIdAndAtivoTrue(1L)).thenReturn(0L);

        TutorResponse resp = service.criar(request("529.982.247-25"));

        ArgumentCaptor<Tutor> captor = ArgumentCaptor.forClass(Tutor.class);
        verify(tutorRepository).save(captor.capture());
        Tutor salvo = captor.getValue();
        assertNotEquals("52998224725", salvo.getCpfCriptografado());
        assertEquals("52998224725", crypto.decifrar(salvo.getCpfCriptografado()));
        assertEquals(crypto.hash("52998224725"), salvo.getCpfHash());
        assertEquals("***.982.247-**", resp.cpfMascarado());
        verify(logService).tutor(eq(1L), eq("CRIACAO"), anyString());
    }

    @Test
    void atualizar_semEnviarCpf_mantemCpfEGravaLog() {
        Tutor existente = Tutor.builder().id(1L).nome("Antigo").telefone("1").email("a@a.com")
                .cpfCriptografado(crypto.cifrar("52998224725")).cpfHash(crypto.hash("52998224725")).build();
        when(tutorRepository.findByIdAndAtivoTrue(1L)).thenReturn(Optional.of(existente));
        when(tutorRepository.save(any(Tutor.class))).thenAnswer(inv -> inv.getArgument(0));
        when(petRepository.countByTutorIdAndAtivoTrue(1L)).thenReturn(1L);

        TutorResponse resp = service.atualizar(1L, request(null));

        assertEquals("Mariana Souza", resp.nome());
        assertEquals(crypto.hash("52998224725"), existente.getCpfHash());
        verify(logService).tutor(eq(1L), eq("ATUALIZACAO"), contains("nome"));
    }

    @Test
    void inativar_tutorComPetsAtivos_lancaBusinessException() {
        Tutor t = Tutor.builder().id(1L).nome("X").build();
        when(tutorRepository.findByIdAndAtivoTrue(1L)).thenReturn(Optional.of(t));
        when(petRepository.countByTutorIdAndAtivoTrue(1L)).thenReturn(2L);
        assertThrows(BusinessException.class, () -> service.inativar(1L));
        verify(tutorRepository, never()).save(any());
    }

    @Test
    void listar_comBusca_usaConsultaDeBusca() {
        when(tutorRepository.buscar(eq("mar"), anyString())).thenReturn(List.of());
        assertTrue(service.listar("mar").isEmpty());
        verify(tutorRepository).buscar(eq("mar"), anyString());
        verify(tutorRepository, never()).findByAtivoTrueOrderByNomeAsc();
    }
}
'@

Write-Utf8NoBom "$TestDir\service\PetServiceTest.java" @'
package br.com.clinicavet.service;

import br.com.clinicavet.dto.PetRequest;
import br.com.clinicavet.dto.PetResponse;
import br.com.clinicavet.exception.NotFoundException;
import br.com.clinicavet.mapper.PetMapper;
import br.com.clinicavet.model.Pet;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.repository.PetRepository;
import br.com.clinicavet.repository.TutorRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PetServiceTest {

    @Mock PetRepository petRepository;
    @Mock TutorRepository tutorRepository;
    @Mock LogService logService;
    private PetService service;

    @BeforeEach
    void setUp() {
        service = new PetService(petRepository, tutorRepository, new PetMapper(), logService);
    }

    @Test
    void criar_semTutorDisponivel_lancaNotFoundException() {
        when(tutorRepository.findByIdAndAtivoTrue(99L)).thenReturn(Optional.empty());
        assertThrows(NotFoundException.class, () -> service.criar(new PetRequest("Rex", "Cão", null, null, 99L)));
        verify(petRepository, never()).save(any());
    }

    @Test
    void criar_comTutorDisponivel_associaPetAoTutorEGravaLog() {
        Tutor tutor = Tutor.builder().id(5L).nome("Carlos").build();
        when(tutorRepository.findByIdAndAtivoTrue(5L)).thenReturn(Optional.of(tutor));
        when(petRepository.save(any(Pet.class))).thenAnswer(inv -> {
            Pet p = inv.getArgument(0);
            p.setId(10L);
            return p;
        });

        PetResponse resp = service.criar(new PetRequest("Rex", "Cão", "SRD", null, 5L));

        assertEquals(5L, resp.tutorId());
        assertEquals("Carlos", resp.tutorNome());
        verify(logService).pet(eq(10L), eq("CRIACAO"), anyString());
    }
}
'@

Write-Utf8NoBom "$TestDir\service\AgendamentoServiceTest.java" @'
package br.com.clinicavet.service;

import br.com.clinicavet.dto.AgendamentoDataRequest;
import br.com.clinicavet.dto.AgendamentoRequest;
import br.com.clinicavet.dto.AgendamentoResponse;
import br.com.clinicavet.exception.BusinessException;
import br.com.clinicavet.exception.ConflictException;
import br.com.clinicavet.mapper.AgendamentoMapper;
import br.com.clinicavet.model.Agendamento;
import br.com.clinicavet.model.Pet;
import br.com.clinicavet.model.StatusAgendamento;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.repository.AgendamentoRepository;
import br.com.clinicavet.repository.PetRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AgendamentoServiceTest {

    @Mock AgendamentoRepository agendamentoRepository;
    @Mock PetRepository petRepository;
    @Mock LogService logService;
    private AgendamentoService service;

    private final Tutor tutor = Tutor.builder().id(1L).nome("Mariana").telefone("7199").build();
    private final Pet pet = Pet.builder().id(10L).nome("Thor").especie("Cão").tutor(tutor).build();

    @BeforeEach
    void setUp() {
        service = new AgendamentoService(agendamentoRepository, petRepository, new AgendamentoMapper(), logService);
    }

    private Agendamento agendamento(LocalDateTime data, StatusAgendamento status) {
        return Agendamento.builder().id(1L).dataHora(data).motivo("Vacina").status(status).pet(pet).build();
    }

    @Test
    void atualizarData_salvaNovaDataERegistraLog() {
        LocalDateTime antiga = LocalDateTime.now().plusDays(2);
        LocalDateTime nova = LocalDateTime.now().plusDays(5);
        when(agendamentoRepository.buscarPorId(1L)).thenReturn(Optional.of(agendamento(antiga, StatusAgendamento.AGENDADO)));
        when(agendamentoRepository.existsByPetIdAndDataHoraAndStatusNot(10L, nova, StatusAgendamento.CANCELADO)).thenReturn(false);
        when(agendamentoRepository.save(any(Agendamento.class))).thenAnswer(inv -> inv.getArgument(0));

        AgendamentoResponse resp = service.atualizarData(1L, new AgendamentoDataRequest(nova));

        assertEquals(nova, resp.dataHora());
        verify(logService).agendamento(eq(1L), eq("REAGENDAMENTO"), anyString(), eq(antiga), eq(nova));
    }

    @Test
    void atualizarData_comDataNoPassado_lancaBusinessException() {
        when(agendamentoRepository.buscarPorId(1L)).thenReturn(Optional.of(agendamento(LocalDateTime.now().plusDays(2), StatusAgendamento.AGENDADO)));
        assertThrows(BusinessException.class,
                () -> service.atualizarData(1L, new AgendamentoDataRequest(LocalDateTime.now().minusDays(1))));
        verify(agendamentoRepository, never()).save(any());
    }

    @Test
    void atualizarData_agendamentoCancelado_naoPermiteReagendar() {
        when(agendamentoRepository.buscarPorId(1L)).thenReturn(Optional.of(agendamento(LocalDateTime.now().plusDays(2), StatusAgendamento.CANCELADO)));
        assertThrows(BusinessException.class,
                () -> service.atualizarData(1L, new AgendamentoDataRequest(LocalDateTime.now().plusDays(3))));
    }

    @Test
    void criar_comConflitoDeHorarioParaOMesmoPet_lancaConflictException() {
        LocalDateTime data = LocalDateTime.now().plusDays(1);
        when(petRepository.buscarAtivoPorId(10L)).thenReturn(Optional.of(pet));
        when(agendamentoRepository.existsByPetIdAndDataHoraAndStatusNot(10L, data, StatusAgendamento.CANCELADO)).thenReturn(true);
        assertThrows(ConflictException.class,
                () -> service.criar(new AgendamentoRequest(data, "Consulta", null, 10L), null));
        verify(agendamentoRepository, never()).save(any());
    }
}
'@

# ---- Infra / Docker / Env / Git / CI-CD ----

Write-Utf8NoBom "$BaseDir\backend\Dockerfile" @'
# ---- Build ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q clean package -DskipTests

# ---- Runtime ----
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S spring && adduser -S spring -G spring
COPY --from=build /app/target/*.jar app.jar
USER spring:spring
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=5 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
'@

Write-Utf8NoBom "$BaseDir\backend\.dockerignore" @'
target/
.git/
.idea/
.vscode/
*.iml
.env
Dockerfile
'@

$envExample = @'
# Copie para .env (backend/.env para rodar local; raiz/.env para docker-compose)
SPRING_PROFILES_ACTIVE=local
SERVER_PORT=8080

DB_NAME=saep_db
DB_ROOT_PASSWORD=root
DB_URL=jdbc:mysql://localhost:3306/saep_db?createDatabaseIfNotExist=true&serverTimezone=America/Bahia&useSSL=false&allowPublicKeyRetrieval=true
DB_USERNAME=root
DB_PASSWORD=root

# Segredos: TROQUE em homologação/produção (JWT precisa de >= 32 caracteres)
JWT_SECRET=troque-este-segredo-jwt-com-mais-de-32-caracteres-aleatorios
JWT_EXPIRATION_MS=60000
CRYPTO_SECRET=troque-este-segredo-aes
CRYPTO_HASH_SECRET=troque-este-segredo-hmac

CORS_ALLOWED_ORIGINS=http://localhost:5173,http://localhost:3000
SEED_ENABLED=true
'@

Write-Utf8NoBom "$BaseDir\.env.example" $envExample
Write-Utf8NoBom "$BaseDir\backend\.env.example" $envExample

Write-Utf8NoBom "$BaseDir\docker-compose.yml" @'
services:
  db:
    image: mysql:8.4
    container_name: clinicavet-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-root}
      MYSQL_DATABASE: ${DB_NAME:-saep_db}
      TZ: America/Bahia
    ports:
      - "3306:3306"
    volumes:
      - db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-p${DB_ROOT_PASSWORD:-root}"]
      interval: 10s
      timeout: 5s
      retries: 10

  backend:
    build: ./backend
    container_name: clinicavet-api
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE:-dev}
      DB_URL: jdbc:mysql://db:3306/${DB_NAME:-saep_db}?serverTimezone=America/Bahia&useSSL=false&allowPublicKeyRetrieval=true
      DB_USERNAME: root
      DB_PASSWORD: ${DB_ROOT_PASSWORD:-root}
      JWT_SECRET: ${JWT_SECRET:-clinica-veterinaria-chave-jwt-super-secreta-trocar-em-producao-2026}
      JWT_EXPIRATION_MS: ${JWT_EXPIRATION_MS:-60000}
      CRYPTO_SECRET: ${CRYPTO_SECRET:-clinica-veterinaria-chave-aes-cpf-dev}
      CRYPTO_HASH_SECRET: ${CRYPTO_HASH_SECRET:-clinica-veterinaria-chave-hmac-cpf-dev}
      CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS:-http://localhost:3000,http://localhost:5173}
      SEED_ENABLED: ${SEED_ENABLED:-true}
    ports:
      - "8080:8080"

  frontend:
    build:
      context: ./frontend
      args:
        VITE_API_URL: http://localhost:8080/api
    container_name: clinicavet-web
    restart: unless-stopped
    depends_on:
      - backend
    ports:
      - "3000:80"

volumes:
  db_data:
'@

Write-Utf8NoBom "$BaseDir\.gitignore" @'
# Java / Maven
target/
*.class
*.log
# Node
node_modules/
dist/
# IDEs
.idea/
.vscode/
*.iml
# Segredos
.env
*.pem
# SO
.DS_Store
Thumbs.db
'@

Write-Utf8NoBom "$BaseDir\.gitattributes" @'
* text=auto eol=lf
*.sh text eol=lf
*.bat text eol=crlf
*.pdf binary
*.png binary
*.jpg binary
*.jar binary
'@

Write-Utf8NoBom "$BaseDir\.github\workflows\ci-cd.yml" @'
name: CI/CD - Clínica Veterinária

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

env:
  REGISTRY: ghcr.io
  IMAGE_PREFIX: ghcr.io/${{ github.repository_owner }}/clinicavet

jobs:
  backend:
    name: Backend (build + testes)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
          cache: maven
      - name: Build e testes (JUnit + Mockito)
        run: mvn -B verify
      - uses: actions/upload-artifact@v4
        with:
          name: backend-jar
          path: backend/target/*.jar

  frontend:
    name: Frontend (build)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: npm
          cache-dependency-path: frontend/package-lock.json
      - run: npm ci
      - run: npm run build

  docker:
    name: Imagens Docker (somente main)
    needs: [backend, frontend]
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          context: ./backend
          push: true
          tags: ${{ env.IMAGE_PREFIX }}-api:latest,${{ env.IMAGE_PREFIX }}-api:${{ github.sha }}
      - uses: docker/build-push-action@v6
        with:
          context: ./frontend
          push: true
          build-args: VITE_API_URL=${{ vars.VITE_API_URL || 'http://localhost:8080/api' }}
          tags: ${{ env.IMAGE_PREFIX }}-web:latest,${{ env.IMAGE_PREFIX }}-web:${{ github.sha }}

  deploy:
    name: Deploy (placeholder)
    needs: docker
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy
        run: echo "Configure aqui o deploy (SSH + docker compose pull/up, Render, Railway, etc.)"
'@

Write-Host "Setup 5 concluído com sucesso em: $BaseDir" -ForegroundColor Green