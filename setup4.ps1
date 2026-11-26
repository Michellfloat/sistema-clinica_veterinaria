# setup5.ps1
$ErrorActionPreference = "Stop"

$base = Join-Path (Get-Location) "backend\src\main\java\br\com\clinicavet"

$pastas = @("security", "config", "service", "controller", "seeder")
foreach ($p in $pastas) {
    New-Item -ItemType Directory -Force -Path (Join-Path $base $p) | Out-Null
}

function Write-Utf8File {
    param([string]$RelPath, [string]$Content)
    $fullPath = Join-Path $base $RelPath
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($fullPath, $Content.TrimStart("`r", "`n"), $utf8NoBom)
}

# ---------- SECURITY ----------
Write-Utf8File "security\JwtService.java" @'
package br.com.clinicavet.security;

import br.com.clinicavet.model.Usuario;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/** Geração e validação do token JWT (expiração curta, padrão 1 minuto). */
@Service
public class JwtService {

    private final SecretKey chave;
    private final long expiracaoMs;

    public JwtService(@Value("${app.jwt.secret}") String segredo,
                      @Value("${app.jwt.expiration-ms}") long expiracaoMs) {
        byte[] bytes = segredo.getBytes(StandardCharsets.UTF_8);
        if (bytes.length < 32) {
            throw new IllegalStateException("app.jwt.secret deve ter pelo menos 32 caracteres.");
        }
        this.chave = Keys.hmacShaKeyFor(bytes);
        this.expiracaoMs = expiracaoMs;
    }

    public long getExpiracaoMs() { return expiracaoMs; }

    public String gerarToken(Usuario usuario, Date expiracao) {
        return Jwts.builder()
                .subject(usuario.getEmail())
                .claim("perfil", usuario.getPerfil().getNome())
                .claim("nome", usuario.getNome())
                .issuedAt(new Date())
                .expiration(expiracao)
                .signWith(chave)
                .compact();
    }

    public Date calcularExpiracao() {
        return new Date(System.currentTimeMillis() + expiracaoMs);
    }

    /** Lança JwtException se o token for inválido, adulterado ou expirado. */
    public String extrairEmail(String token) {
        return claims(token).getSubject();
    }

    private Claims claims(String token) {
        return Jwts.parser().verifyWith(chave).build().parseSignedClaims(token).getPayload();
    }
}
'@

Write-Utf8File "security\JwtAuthFilter.java" @'
package br.com.clinicavet.security;

import br.com.clinicavet.repository.UsuarioRepository;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/** Lê o header Authorization: Bearer ... e autentica a requisição. (Não é @Component de propósito: é registrado no SecurityFilterChain.) */
@Slf4j
public class JwtAuthFilter extends OncePerRequestFilter {

    public static final String ATRIBUTO_EXPIRADO = "jwt.expirado";

    private final JwtService jwtService;
    private final UsuarioRepository usuarioRepository;

    public JwtAuthFilter(JwtService jwtService, UsuarioRepository usuarioRepository) {
        this.jwtService = jwtService;
        this.usuarioRepository = usuarioRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            try {
                String email = jwtService.extrairEmail(header.substring(7));
                usuarioRepository.findByEmail(email).filter(u -> u.isEnabled()).ifPresent(usuario -> {
                    var auth = new UsernamePasswordAuthenticationToken(usuario, null, usuario.getAuthorities());
                    auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(auth);
                });
            } catch (ExpiredJwtException e) {
                request.setAttribute(ATRIBUTO_EXPIRADO, true);
            } catch (JwtException | IllegalArgumentException e) {
                log.debug("Token inválido: {}", e.getMessage());
            }
        }
        chain.doFilter(request, response);
    }
}
'@

Write-Utf8File "security\SecurityConfig.java" @'
package br.com.clinicavet.security;

import br.com.clinicavet.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtService jwtService;
    private final UsuarioRepository usuarioRepository;

    @Value("${app.cors.allowed-origins}")
    private String origensPermitidas;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .cors(c -> c.configurationSource(corsConfigurationSource()))
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(a -> a
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                .requestMatchers("/api/auth/login", "/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html",
                                 "/actuator/health/**").permitAll()
                .requestMatchers("/api/usuarios/**", "/api/logs/**").hasRole("ADMIN")
                .requestMatchers("/api/tutores/**", "/api/dashboard").hasAnyRole("ADMIN", "USUARIO")
                .requestMatchers(HttpMethod.GET, "/api/pets/**", "/api/agendamentos/**")
                    .hasAnyRole("ADMIN", "USUARIO", "TUTOR", "PET")
                .requestMatchers("/api/pets/**", "/api/agendamentos/**").hasAnyRole("ADMIN", "USUARIO")
                .anyRequest().authenticated())
            .exceptionHandling(e -> e
                .authenticationEntryPoint((req, res, ex) -> {
                    boolean expirado = req.getAttribute(JwtAuthFilter.ATRIBUTO_EXPIRADO) != null;
                    escrever(res, 401, "Unauthorized",
                            expirado ? "Sessão expirada. Faça login novamente." : "Autenticação necessária.");
                })
                .accessDeniedHandler((req, res, ex) ->
                    escrever(res, 403, "Forbidden", "Você não tem permissão para acessar este recurso.")))
            .addFilterBefore(new JwtAuthFilter(jwtService, usuarioRepository), UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    private void escrever(jakarta.servlet.http.HttpServletResponse res, int status, String erro, String msg)
            throws java.io.IOException {
        res.setStatus(status);
        res.setContentType(MediaType.APPLICATION_JSON_VALUE);
        res.setCharacterEncoding("UTF-8");
        res.getWriter().write("{\"status\":" + status + ",\"erro\":\"" + erro + "\",\"mensagem\":\"" + msg + "\"}");
    }

    @Bean
    public UserDetailsService userDetailsService() {
        return email -> usuarioRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("Usuário não encontrado"));
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration cfg = new CorsConfiguration();
        cfg.setAllowedOrigins(Arrays.stream(origensPermitidas.split(",")).map(String::trim).toList());
        cfg.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        cfg.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", cfg);
        return source;
    }
}
'@

Write-Utf8File "config\OpenApiConfig.java" @'
package br.com.clinicavet.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI openAPI() {
        return new OpenAPI()
                .info(new Info().title("API - Clínica Veterinária")
                        .description("Agendamentos, tutores e pets. Autenticação JWT com expiração curta.")
                        .version("1.0.0"))
                .addSecurityItem(new SecurityRequirement().addList("bearer-jwt"))
                .components(new Components().addSecuritySchemes("bearer-jwt",
                        new SecurityScheme().type(SecurityScheme.Type.HTTP).scheme("bearer").bearerFormat("JWT")));
    }
}
'@

# ---------- SERVICES ----------
Write-Utf8File "service\CryptoService.java" @'
package br.com.clinicavet.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import javax.crypto.Mac;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;

/**
 * Proteção de dados pessoais (LGPD): AES-256-GCM para cifrar o CPF e HMAC-SHA256 para
 * gerar um índice pesquisável/único sem expor o valor original.
 * Formato do cifrado: Base64( IV[12] + CIPHERTEXT + TAG[16] ).
 */
@Service
public class CryptoService {

    private static final int IV_BYTES = 12;
    private static final int TAG_BITS = 128;

    private final SecretKeySpec chaveAes;
    private final SecretKeySpec chaveHmac;
    private final SecureRandom random = new SecureRandom();

    public CryptoService(@Value("${app.crypto.secret}") String segredo,
                         @Value("${app.crypto.hash-secret}") String segredoHash) {
        this.chaveAes = new SecretKeySpec(sha256(segredo), "AES");
        this.chaveHmac = new SecretKeySpec(sha256(segredoHash), "HmacSHA256");
    }

    public String cifrar(String textoPuro) {
        try {
            byte[] iv = new byte[IV_BYTES];
            random.nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, chaveAes, new GCMParameterSpec(TAG_BITS, iv));
            byte[] cifrado = cipher.doFinal(textoPuro.getBytes(StandardCharsets.UTF_8));
            byte[] saida = new byte[iv.length + cifrado.length];
            System.arraycopy(iv, 0, saida, 0, iv.length);
            System.arraycopy(cifrado, 0, saida, iv.length, cifrado.length);
            return Base64.getEncoder().encodeToString(saida);
        } catch (Exception e) {
            throw new IllegalStateException("Falha ao criptografar dado sensível", e);
        }
    }

    public String decifrar(String base64) {
        try {
            byte[] entrada = Base64.getDecoder().decode(base64);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, chaveAes, new GCMParameterSpec(TAG_BITS, entrada, 0, IV_BYTES));
            byte[] puro = cipher.doFinal(entrada, IV_BYTES, entrada.length - IV_BYTES);
            return new String(puro, StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new IllegalStateException("Falha ao descriptografar dado sensível", e);
        }
    }

    /** HMAC-SHA256 em hexadecimal (64 caracteres) do valor informado. */
    public String hash(String valor) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(chaveHmac);
            return HexFormat.of().formatHex(mac.doFinal(valor.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("Falha ao gerar hash", e);
        }
    }

    private static byte[] sha256(String s) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
'@

Write-Utf8File "service\LogService.java" @'
package br.com.clinicavet.service;

import br.com.clinicavet.dto.LogResponse;
import br.com.clinicavet.model.*;
import br.com.clinicavet.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/** Registra o histórico de atualizações de cada funcionalidade (tabelas log_*). */
@Service
@RequiredArgsConstructor
public class LogService {

    private final LogTutorRepository logTutorRepository;
    private final LogPetRepository logPetRepository;
    private final LogAgendamentoRepository logAgendamentoRepository;
    private final LogUsuarioRepository logUsuarioRepository;

    private String emailAtual() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        if (a == null || !a.isAuthenticated() || a instanceof AnonymousAuthenticationToken) return "SISTEMA";
        return a.getName();
    }

    public void tutor(Long tutorId, String acao, String descricao) {
        logTutorRepository.save(LogTutor.builder().tutorId(tutorId).acao(acao).descricao(cortar(descricao))
                .usuarioEmail(emailAtual()).dataHora(LocalDateTime.now()).build());
    }

    public void pet(Long petId, String acao, String descricao) {
        logPetRepository.save(LogPet.builder().petId(petId).acao(acao).descricao(cortar(descricao))
                .usuarioEmail(emailAtual()).dataHora(LocalDateTime.now()).build());
    }

    public void agendamento(Long id, String acao, String descricao, LocalDateTime anterior, LocalDateTime nova) {
        logAgendamentoRepository.save(LogAgendamento.builder().agendamentoId(id).acao(acao).descricao(cortar(descricao))
                .dataAnterior(anterior).dataNova(nova).usuarioEmail(emailAtual()).dataHora(LocalDateTime.now()).build());
    }

    public void usuario(Long usuarioId, String acao, String descricao, String autorEmail) {
        logUsuarioRepository.save(LogUsuario.builder().usuarioId(usuarioId).acao(acao).descricao(cortar(descricao))
                .usuarioEmail(autorEmail != null ? autorEmail : emailAtual()).dataHora(LocalDateTime.now()).build());
    }

    @Transactional(readOnly = true)
    public List<LogResponse> listarTodos() {
        List<LogResponse> todos = new ArrayList<>();
        logTutorRepository.findTop100ByOrderByDataHoraDesc().forEach(l ->
                todos.add(new LogResponse(l.getId(), "TUTOR", l.getTutorId(), l.getAcao(), l.getDescricao(), l.getUsuarioEmail(), l.getDataHora())));
        logPetRepository.findTop100ByOrderByDataHoraDesc().forEach(l ->
                todos.add(new LogResponse(l.getId(), "PET", l.getPetId(), l.getAcao(), l.getDescricao(), l.getUsuarioEmail(), l.getDataHora())));
        logAgendamentoRepository.findTop100ByOrderByDataHoraDesc().forEach(l ->
                todos.add(new LogResponse(l.getId(), "AGENDAMENTO", l.getAgendamentoId(), l.getAcao(), l.getDescricao(), l.getUsuarioEmail(), l.getDataHora())));
        logUsuarioRepository.findTop100ByOrderByDataHoraDesc().forEach(l ->
                todos.add(new LogResponse(l.getId(), "USUARIO", l.getUsuarioId(), l.getAcao(), l.getDescricao(), l.getUsuarioEmail(), l.getDataHora())));
        todos.sort(Comparator.comparing(LogResponse::dataHora).reversed());
        return todos.size() > 100 ? todos.subList(0, 100) : todos;
    }

    private String cortar(String s) {
        return s != null && s.length() > 500 ? s.substring(0, 497) + "..." : s;
    }
}
'@

Write-Utf8File "service\AuthService.java" @'
package br.com.clinicavet.service;

import br.com.clinicavet.dto.LoginRequest;
import br.com.clinicavet.dto.LoginResponse;
import br.com.clinicavet.mapper.UsuarioMapper;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

import java.util.Date;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;
    private final UsuarioMapper usuarioMapper;
    private final LogService logService;

    /** Falhas de autenticação lançam BadCredentialsException (tratada no GlobalExceptionHandler => 401). */
    public LoginResponse login(LoginRequest req) {
        Authentication auth = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(req.email().trim().toLowerCase(), req.senha()));
        Usuario usuario = (Usuario) auth.getPrincipal();

        Date expiracao = jwtService.calcularExpiracao();
        String token = jwtService.gerarToken(usuario, expiracao);
        logService.usuario(usuario.getId(), "LOGIN", "Login realizado com sucesso", usuario.getEmail());

        return new LoginResponse(token, "Bearer", expiracao.getTime(), jwtService.getExpiracaoMs() / 1000,
                usuarioMapper.toResponse(usuario));
    }
}
'@

Write-Utf8File "service\TutorService.java" @'
package br.com.clinicavet.service;

import br.com.clinicavet.dto.TutorRequest;
import br.com.clinicavet.dto.TutorResponse;
import br.com.clinicavet.exception.BusinessException;
import br.com.clinicavet.exception.ConflictException;
import br.com.clinicavet.exception.NotFoundException;
import br.com.clinicavet.mapper.TutorMapper;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.repository.PetRepository;
import br.com.clinicavet.repository.TutorRepository;
import br.com.clinicavet.util.CpfUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class TutorService {

    private final TutorRepository tutorRepository;
    private final PetRepository petRepository;
    private final CryptoService crypto;
    private final TutorMapper mapper;
    private final LogService logService;

    /** Sem termo: lista todos. Com termo: filtra por nome, e-mail, telefone ou CPF (busca exata). */
    @Transactional(readOnly = true)
    public List<TutorResponse> listar(String busca) {
        List<Tutor> tutores;
        if (busca == null || busca.isBlank()) {
            tutores = tutorRepository.findByAtivoTrueOrderByNomeAsc();
        } else {
            String termo = busca.trim();
            tutores = tutorRepository.buscar(termo, crypto.hash(CpfUtil.limpar(termo)));
        }
        return tutores.stream().map(this::paraResponse).toList();
    }

    @Transactional(readOnly = true)
    public TutorResponse buscarPorId(Long id) {
        return paraResponse(obter(id));
    }

    @Transactional
    public TutorResponse criar(TutorRequest req) {
        String cpf = CpfUtil.limpar(req.cpf());
        if (!CpfUtil.valido(cpf)) throw new BusinessException("CPF inválido.");
        String hash = crypto.hash(cpf);
        if (tutorRepository.existsByCpfHash(hash)) throw new ConflictException("Já existe um tutor cadastrado com este CPF.");

        Tutor tutor = Tutor.builder()
                .nome(req.nome().trim()).telefone(req.telefone().trim()).email(req.email().trim().toLowerCase())
                .endereco(req.endereco()).cpfCriptografado(crypto.cifrar(cpf)).cpfHash(hash).build();
        tutor = tutorRepository.save(tutor);
        logService.tutor(tutor.getId(), "CRIACAO", "Tutor cadastrado: " + tutor.getNome());
        return paraResponse(tutor);
    }

    @Transactional
    public TutorResponse atualizar(Long id, TutorRequest req) {
        Tutor tutor = obter(id);
        List<String> alteracoes = new ArrayList<>();

        if (!tutor.getNome().equals(req.nome().trim())) alteracoes.add("nome '" + tutor.getNome() + "' -> '" + req.nome().trim() + "'");
        if (!tutor.getTelefone().equals(req.telefone().trim())) alteracoes.add("telefone '" + tutor.getTelefone() + "' -> '" + req.telefone().trim() + "'");
        if (!tutor.getEmail().equalsIgnoreCase(req.email().trim())) alteracoes.add("e-mail '" + tutor.getEmail() + "' -> '" + req.email().trim().toLowerCase() + "'");
        if (req.endereco() != null && !req.endereco().equals(tutor.getEndereco())) alteracoes.add("endereço alterado");

        tutor.setNome(req.nome().trim());
        tutor.setTelefone(req.telefone().trim());
        tutor.setEmail(req.email().trim().toLowerCase());
        tutor.setEndereco(req.endereco());

        if (req.cpf() != null && !req.cpf().isBlank()) {
            String cpf = CpfUtil.limpar(req.cpf());
            if (!CpfUtil.valido(cpf)) throw new BusinessException("CPF inválido.");
            String hash = crypto.hash(cpf);
            if (!hash.equals(tutor.getCpfHash())) {
                if (tutorRepository.existsByCpfHashAndIdNot(hash, id)) throw new ConflictException("Já existe um tutor cadastrado com este CPF.");
                tutor.setCpfHash(hash);
                tutor.setCpfCriptografado(crypto.cifrar(cpf));
                alteracoes.add("CPF atualizado"); // o valor nunca é registrado no log
            }
        }

        tutor = tutorRepository.save(tutor);
        logService.tutor(id, "ATUALIZACAO", alteracoes.isEmpty() ? "Cadastro salvo sem alterações" : "Alterado: " + String.join("; ", alteracoes));
        return paraResponse(tutor);
    }

    @Transactional
    public void inativar(Long id) {
        Tutor tutor = obter(id);
        if (petRepository.countByTutorIdAndAtivoTrue(id) > 0) {
            throw new BusinessException("Não é possível remover um tutor que possui pets ativos. Transfira ou remova os pets primeiro.");
        }
        tutor.setAtivo(false);
        tutorRepository.save(tutor);
        logService.tutor(id, "REMOCAO", "Tutor inativado: " + tutor.getNome());
    }

    private Tutor obter(Long id) {
        return tutorRepository.findByIdAndAtivoTrue(id).orElseThrow(() -> new NotFoundException("Tutor não encontrado."));
    }

    private TutorResponse paraResponse(Tutor t) {
        return mapper.toResponse(t, petRepository.countByTutorIdAndAtivoTrue(t.getId()));
    }
}
'@

Write-Utf8File "service\PetService.java" @'
package br.com.clinicavet.service;

import br.com.clinicavet.dto.PetRequest;
import br.com.clinicavet.dto.PetResponse;
import br.com.clinicavet.exception.NotFoundException;
import br.com.clinicavet.mapper.PetMapper;
import br.com.clinicavet.model.Pet;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.repository.PetRepository;
import br.com.clinicavet.repository.TutorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class PetService {

    private final PetRepository petRepository;
    private final TutorRepository tutorRepository;
    private final PetMapper mapper;
    private final LogService logService;

    @Transactional(readOnly = true)
    public List<PetResponse> listar(String busca, Usuario usuario) {
        List<Pet> pets;
        if (somenteProprios(usuario)) {
            pets = usuario.getTutor() == null ? List.of() : petRepository.listarPorTutor(usuario.getTutor().getId());
        } else if (busca == null || busca.isBlank()) {
            pets = petRepository.listarAtivos();
        } else {
            pets = petRepository.buscar(busca.trim());
        }
        return pets.stream().map(mapper::toResponse).toList();
    }

    @Transactional
    public PetResponse criar(PetRequest req) {
        Tutor tutor = tutorDisponivel(req.tutorId());
        Pet pet = Pet.builder().nome(req.nome().trim()).especie(req.especie().trim()).raca(req.raca())
                .dataNascimento(req.dataNascimento()).tutor(tutor).build();
        pet = petRepository.save(pet);
        logService.pet(pet.getId(), "CRIACAO", "Pet cadastrado: " + pet.getNome() + " (tutor: " + tutor.getNome() + ")");
        return mapper.toResponse(pet);
    }

    @Transactional
    public PetResponse atualizar(Long id, PetRequest req) {
        Pet pet = obter(id);
        Tutor tutor = tutorDisponivel(req.tutorId());
        String detalhe = "Pet atualizado: " + pet.getNome() + " -> " + req.nome().trim();
        if (!pet.getTutor().getId().equals(tutor.getId())) detalhe += "; tutor: " + pet.getTutor().getNome() + " -> " + tutor.getNome();
        pet.setNome(req.nome().trim());
        pet.setEspecie(req.especie().trim());
        pet.setRaca(req.raca());
        pet.setDataNascimento(req.dataNascimento());
        pet.setTutor(tutor);
        pet = petRepository.save(pet);
        logService.pet(id, "ATUALIZACAO", detalhe);
        return mapper.toResponse(pet);
    }

    @Transactional
    public void inativar(Long id) {
        Pet pet = obter(id);
        pet.setAtivo(false);
        petRepository.save(pet);
        logService.pet(id, "REMOCAO", "Pet inativado: " + pet.getNome());
    }

    /** Regra: todo pet deve ser associado a um tutor disponível (existente e ativo). */
    private Tutor tutorDisponivel(Long tutorId) {
        return tutorRepository.findByIdAndAtivoTrue(tutorId)
                .orElseThrow(() -> new NotFoundException("Tutor indisponível. Associe o pet a um tutor cadastrado."));
    }

    private Pet obter(Long id) {
        return petRepository.buscarAtivoPorId(id).orElseThrow(() -> new NotFoundException("Pet não encontrado."));
    }

    static boolean somenteProprios(Usuario usuario) {
        if (usuario == null) return false;
        String p = usuario.getPerfil().getNome();
        return p.equals("TUTOR") || p.equals("PET");
    }
}
'@

Write-Utf8File "service\AgendamentoService.java" @'
package br.com.clinicavet.service;

import br.com.clinicavet.dto.AgendamentoDataRequest;
import br.com.clinicavet.dto.AgendamentoRequest;
import br.com.clinicavet.dto.AgendamentoResponse;
import br.com.clinicavet.dto.AgendamentoStatusRequest;
import br.com.clinicavet.exception.BusinessException;
import br.com.clinicavet.exception.ConflictException;
import br.com.clinicavet.exception.NotFoundException;
import br.com.clinicavet.mapper.AgendamentoMapper;
import br.com.clinicavet.model.Agendamento;
import br.com.clinicavet.model.Pet;
import br.com.clinicavet.model.StatusAgendamento;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.repository.AgendamentoRepository;
import br.com.clinicavet.repository.PetRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AgendamentoService {

    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

    private final AgendamentoRepository agendamentoRepository;
    private final PetRepository petRepository;
    private final AgendamentoMapper mapper;
    private final LogService logService;

    /** Listagem ordenada por dia/hora do agendamento, com dados do tutor e do pet. */
    @Transactional(readOnly = true)
    public List<AgendamentoResponse> listar(Usuario usuario) {
        List<Agendamento> lista;
        if (PetService.somenteProprios(usuario)) {
            lista = usuario.getTutor() == null ? List.of() : agendamentoRepository.listarPorTutor(usuario.getTutor().getId());
        } else {
            lista = agendamentoRepository.listarOrdenados();
        }
        return lista.stream().map(mapper::toResponse).toList();
    }

    @Transactional
    public AgendamentoResponse criar(AgendamentoRequest req, Usuario responsavel) {
        Pet pet = petRepository.buscarAtivoPorId(req.petId()).orElseThrow(() -> new NotFoundException("Pet não encontrado."));
        validarData(req.dataHora());
        validarConflito(pet.getId(), req.dataHora());

        Agendamento ag = Agendamento.builder().dataHora(req.dataHora()).motivo(req.motivo().trim())
                .observacoes(req.observacoes()).pet(pet).usuario(responsavel).status(StatusAgendamento.AGENDADO).build();
        ag = agendamentoRepository.save(ag);
        logService.agendamento(ag.getId(), "CRIACAO",
                "Agendamento criado para " + pet.getNome() + " em " + ag.getDataHora().format(FMT), null, ag.getDataHora());
        return mapper.toResponse(ag);
    }

    /** Atualiza somente a data/hora de um agendamento já cadastrado e registra no log_agendamento. */
    @Transactional
    public AgendamentoResponse atualizarData(Long id, AgendamentoDataRequest req) {
        Agendamento ag = obter(id);
        if (ag.getStatus() == StatusAgendamento.CANCELADO || ag.getStatus() == StatusAgendamento.CONCLUIDO) {
            throw new BusinessException("Agendamentos cancelados ou concluídos não podem ser reagendados.");
        }
        validarData(req.dataHora());
        if (!req.dataHora().equals(ag.getDataHora())) validarConflito(ag.getPet().getId(), req.dataHora());

        LocalDateTime anterior = ag.getDataHora();
        ag.setDataHora(req.dataHora());
        ag = agendamentoRepository.save(ag);
        logService.agendamento(id, "REAGENDAMENTO",
                "Data alterada de " + anterior.format(FMT) + " para " + req.dataHora().format(FMT), anterior, req.dataHora());
        return mapper.toResponse(ag);
    }

    @Transactional
    public AgendamentoResponse atualizarStatus(Long id, AgendamentoStatusRequest req) {
        Agendamento ag = obter(id);
        StatusAgendamento anterior = ag.getStatus();
        ag.setStatus(req.status());
        ag = agendamentoRepository.save(ag);
        logService.agendamento(id, "STATUS", "Status alterado de " + anterior + " para " + req.status(), null, null);
        return mapper.toResponse(ag);
    }

    private Agendamento obter(Long id) {
        return agendamentoRepository.buscarPorId(id).orElseThrow(() -> new NotFoundException("Agendamento não encontrado."));
    }

    private void validarData(LocalDateTime dataHora) {
        if (!dataHora.isAfter(LocalDateTime.now())) throw new BusinessException("Escolha uma data e hora futuras.");
    }

    private void validarConflito(Long petId, LocalDateTime dataHora) {
        if (agendamentoRepository.existsByPetIdAndDataHoraAndStatusNot(petId, dataHora, StatusAgendamento.CANCELADO)) {
            throw new ConflictException("Este pet já possui um agendamento nesse horário.");
        }
    }
}
'@

Write-Utf8File "service\UsuarioService.java" @'
package br.com.clinicavet.service;

import br.com.clinicavet.dto.UsuarioRequest;
import br.com.clinicavet.dto.UsuarioResponse;
import br.com.clinicavet.exception.BusinessException;
import br.com.clinicavet.exception.ConflictException;
import br.com.clinicavet.exception.NotFoundException;
import br.com.clinicavet.mapper.UsuarioMapper;
import br.com.clinicavet.model.Perfil;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.repository.PerfilRepository;
import br.com.clinicavet.repository.TutorRepository;
import br.com.clinicavet.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class UsuarioService {

    private final UsuarioRepository usuarioRepository;
    private final PerfilRepository perfilRepository;
    private final TutorRepository tutorRepository;
    private final PasswordEncoder passwordEncoder;
    private final UsuarioMapper mapper;
    private final LogService logService;

    @Transactional(readOnly = true)
    public List<UsuarioResponse> listar() {
        return usuarioRepository.findAll().stream().map(mapper::toResponse).toList();
    }

    @Transactional
    public UsuarioResponse criar(UsuarioRequest req) {
        String email = req.email().trim().toLowerCase();
        if (req.senha() == null || req.senha().length() < 6) throw new BusinessException("Informe uma senha com pelo menos 6 caracteres.");
        if (usuarioRepository.existsByEmail(email)) throw new ConflictException("Já existe um usuário com este e-mail.");

        Usuario u = Usuario.builder().nome(req.nome().trim()).email(email).senha(passwordEncoder.encode(req.senha()))
                .fotoUrl(req.fotoUrl()).perfil(perfil(req.perfil())).tutor(tutor(req.tutorId()))
                .ativo(req.ativo() == null || req.ativo()).build();
        u = usuarioRepository.save(u);
        logService.usuario(u.getId(), "CRIACAO", "Usuário criado: " + u.getEmail() + " (" + u.getPerfil().getNome() + ")", null);
        return mapper.toResponse(u);
    }

    @Transactional
    public UsuarioResponse atualizar(Long id, UsuarioRequest req) {
        Usuario u = usuarioRepository.findById(id).orElseThrow(() -> new NotFoundException("Usuário não encontrado."));
        u.setNome(req.nome().trim());
        u.setFotoUrl(req.fotoUrl());
        u.setPerfil(perfil(req.perfil()));
        u.setTutor(tutor(req.tutorId()));
        if (req.ativo() != null) u.setAtivo(req.ativo());
        if (req.senha() != null && !req.senha().isBlank()) u.setSenha(passwordEncoder.encode(req.senha()));
        u = usuarioRepository.save(u);
        logService.usuario(id, "ATUALIZACAO", "Usuário atualizado: " + u.getEmail() + " (perfil " + u.getPerfil().getNome() + ", ativo=" + u.getAtivo() + ")", null);
        return mapper.toResponse(u);
    }

    private Perfil perfil(String nome) {
        return perfilRepository.findByNome(nome.trim().toUpperCase()).orElseThrow(() -> new BusinessException("Perfil inválido."));
    }

    private Tutor tutor(Long id) {
        if (id == null) return null;
        return tutorRepository.findByIdAndAtivoTrue(id).orElseThrow(() -> new NotFoundException("Tutor vinculado não encontrado."));
    }
}
'@

Write-Utf8File "service\DashboardService.java" @'
package br.com.clinicavet.service;

import br.com.clinicavet.dto.AgendamentoResponse;
import br.com.clinicavet.dto.DashboardResponse;
import br.com.clinicavet.mapper.AgendamentoMapper;
import br.com.clinicavet.model.StatusAgendamento;
import br.com.clinicavet.repository.AgendamentoRepository;
import br.com.clinicavet.repository.PetRepository;
import br.com.clinicavet.repository.TutorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DashboardService {

    private final TutorRepository tutorRepository;
    private final PetRepository petRepository;
    private final AgendamentoRepository agendamentoRepository;
    private final AgendamentoMapper agendamentoMapper;

    @Transactional(readOnly = true)
    public DashboardResponse resumo() {
        LocalDate hoje = LocalDate.now();
        long agendamentosHoje = agendamentoRepository.countByDataHoraBetweenAndStatusNot(
                hoje.atStartOfDay(), hoje.plusDays(1).atStartOfDay(), StatusAgendamento.CANCELADO);
        LocalDateTime agora = LocalDateTime.now();
        List<AgendamentoResponse> proximos = agendamentoRepository.listarOrdenados().stream()
                .filter(a -> a.getDataHora().isAfter(agora) && a.getStatus() != StatusAgendamento.CANCELADO)
                .limit(5).map(agendamentoMapper::toResponse).toList();
        return new DashboardResponse(tutorRepository.countByAtivoTrue(), petRepository.countByAtivoTrue(), agendamentosHoje, proximos);
    }
}
'@

# ---------- CONTROLLERS ----------
Write-Utf8File "controller\AuthController.java" @'
package br.com.clinicavet.controller;

import br.com.clinicavet.dto.LoginRequest;
import br.com.clinicavet.dto.LoginResponse;
import br.com.clinicavet.dto.UsuarioResponse;
import br.com.clinicavet.mapper.UsuarioMapper;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Tag(name = "Autenticação")
public class AuthController {

    private final AuthService authService;
    private final UsuarioMapper usuarioMapper;

    @PostMapping("/login")
    @Operation(summary = "Autentica e devolve o JWT (expira em ~1 minuto)")
    public LoginResponse login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }

    @GetMapping("/me")
    @Operation(summary = "Dados do usuário logado")
    public UsuarioResponse me(@AuthenticationPrincipal Usuario usuario) {
        return usuarioMapper.toResponse(usuario);
    }
}
'@

Write-Utf8File "controller\TutorController.java" @'
package br.com.clinicavet.controller;

import br.com.clinicavet.dto.TutorRequest;
import br.com.clinicavet.dto.TutorResponse;
import br.com.clinicavet.service.TutorService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/tutores")
@RequiredArgsConstructor
@Tag(name = "Tutores")
public class TutorController {

    private final TutorService service;

    @GetMapping
    @Operation(summary = "Lista tutores; com ?busca= filtra por nome, e-mail, telefone ou CPF")
    public List<TutorResponse> listar(@RequestParam(required = false) String busca) {
        return service.listar(busca);
    }

    @GetMapping("/{id}")
    public TutorResponse buscar(@PathVariable Long id) { return service.buscarPorId(id); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public TutorResponse criar(@Valid @RequestBody TutorRequest req) { return service.criar(req); }

    @PutMapping("/{id}")
    @Operation(summary = "Edita os dados de um tutor já cadastrado")
    public TutorResponse atualizar(@PathVariable Long id, @Valid @RequestBody TutorRequest req) {
        return service.atualizar(id, req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remover(@PathVariable Long id) { service.inativar(id); }
}
'@

Write-Utf8File "controller\PetController.java" @'
package br.com.clinicavet.controller;

import br.com.clinicavet.dto.PetRequest;
import br.com.clinicavet.dto.PetResponse;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.service.PetService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/pets")
@RequiredArgsConstructor
@Tag(name = "Pets")
public class PetController {

    private final PetService service;

    @GetMapping
    public List<PetResponse> listar(@RequestParam(required = false) String busca, @AuthenticationPrincipal Usuario usuario) {
        return service.listar(busca, usuario);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PetResponse criar(@Valid @RequestBody PetRequest req) { return service.criar(req); }

    @PutMapping("/{id}")
    public PetResponse atualizar(@PathVariable Long id, @Valid @RequestBody PetRequest req) { return service.atualizar(id, req); }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remover(@PathVariable Long id) { service.inativar(id); }
}
'@

Write-Utf8File "controller\AgendamentoController.java" @'
package br.com.clinicavet.controller;

import br.com.clinicavet.dto.AgendamentoDataRequest;
import br.com.clinicavet.dto.AgendamentoRequest;
import br.com.clinicavet.dto.AgendamentoResponse;
import br.com.clinicavet.dto.AgendamentoStatusRequest;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.service.AgendamentoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/agendamentos")
@RequiredArgsConstructor
@Tag(name = "Agendamentos")
public class AgendamentoController {

    private final AgendamentoService service;

    @GetMapping
    @Operation(summary = "Lista agendamentos ordenados por dia, com dados do tutor e do pet")
    public List<AgendamentoResponse> listar(@AuthenticationPrincipal Usuario usuario) { return service.listar(usuario); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AgendamentoResponse criar(@Valid @RequestBody AgendamentoRequest req, @AuthenticationPrincipal Usuario usuario) {
        return service.criar(req, usuario);
    }

    @PatchMapping("/{id}/data")
    @Operation(summary = "Atualiza a data de um agendamento (gera registro em log_agendamento)")
    public AgendamentoResponse atualizarData(@PathVariable Long id, @Valid @RequestBody AgendamentoDataRequest req) {
        return service.atualizarData(id, req);
    }

    @PatchMapping("/{id}/status")
    public AgendamentoResponse atualizarStatus(@PathVariable Long id, @Valid @RequestBody AgendamentoStatusRequest req) {
        return service.atualizarStatus(id, req);
    }
}
'@

Write-Utf8File "controller\UsuarioController.java" @'
package br.com.clinicavet.controller;

import br.com.clinicavet.dto.UsuarioRequest;
import br.com.clinicavet.dto.UsuarioResponse;
import br.com.clinicavet.service.UsuarioService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/usuarios")
@RequiredArgsConstructor
@Tag(name = "Usuários (ADMIN)")
public class UsuarioController {

    private final UsuarioService service;

    @GetMapping
    public List<UsuarioResponse> listar() { return service.listar(); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UsuarioResponse criar(@Valid @RequestBody UsuarioRequest req) { return service.criar(req); }

    @PutMapping("/{id}")
    public UsuarioResponse atualizar(@PathVariable Long id, @Valid @RequestBody UsuarioRequest req) { return service.atualizar(id, req); }
}
'@

Write-Utf8File "controller\LogController.java" @'
package br.com.clinicavet.controller;

import br.com.clinicavet.dto.LogResponse;
import br.com.clinicavet.service.LogService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/logs")
@RequiredArgsConstructor
@Tag(name = "Logs de atualização (ADMIN)")
public class LogController {

    private final LogService service;

    @GetMapping
    public List<LogResponse> listar() { return service.listarTodos(); }
}
'@

Write-Utf8File "controller\DashboardController.java" @'
package br.com.clinicavet.controller;

import br.com.clinicavet.dto.DashboardResponse;
import br.com.clinicavet.service.DashboardService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/dashboard")
@RequiredArgsConstructor
@Tag(name = "Dashboard")
public class DashboardController {

    private final DashboardService service;

    @GetMapping
    public DashboardResponse resumo() { return service.resumo(); }
}
'@

# ---------- SEEDER ----------
Write-Utf8File "seeder\DataInitializer.java" @'
package br.com.clinicavet.seeder;

import br.com.clinicavet.dto.*;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.repository.TutorRepository;
import br.com.clinicavet.repository.UsuarioRepository;
import br.com.clinicavet.service.AgendamentoService;
import br.com.clinicavet.service.PetService;
import br.com.clinicavet.service.TutorService;
import br.com.clinicavet.service.UsuarioService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

/** Popula o banco com dados de exemplo (mínimo de 3 registros por tabela). Só roda se o banco estiver vazio. */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.seed.enabled", havingValue = "true")
public class DataInitializer implements ApplicationRunner {

    private final TutorService tutorService;
    private final PetService petService;
    private final AgendamentoService agendamentoService;
    private final UsuarioService usuarioService;
    private final TutorRepository tutorRepository;
    private final UsuarioRepository usuarioRepository;

    @Override
    public void run(ApplicationArguments args) {
        if (tutorRepository.count() > 0 || usuarioRepository.count() > 0) {
            log.info("Seed ignorado: o banco já possui dados.");
            return;
        }
        log.info("Populando banco com dados de exemplo...");

        Long t1 = tutorService.criar(new TutorRequest("Mariana Souza", "529.982.247-25", "(71) 99811-2233", "mariana.souza@email.com", "Rua das Acácias, 120 - Pituba, Salvador/BA")).id();
        Long t2 = tutorService.criar(new TutorRequest("Carlos Eduardo Lima", "111.444.777-35", "(71) 98822-4455", "carlos.lima@email.com", "Av. Oceânica, 900 - Barra, Salvador/BA")).id();
        Long t3 = tutorService.criar(new TutorRequest("Fernanda Oliveira", "935.411.347-80", "(71) 99700-1010", "fernanda.o@email.com", "Rua da Paz, 45 - Rio Vermelho, Salvador/BA")).id();

        Long p1 = petService.criar(new PetRequest("Thor", "Cão", "Golden Retriever", LocalDate.of(2020, 3, 14), t1)).id();
        Long p2 = petService.criar(new PetRequest("Mel", "Gato", "Siamês", LocalDate.of(2021, 7, 2), t2)).id();
        Long p3 = petService.criar(new PetRequest("Bob", "Cão", "Vira-lata", LocalDate.of(2019, 11, 20), t3)).id();
        petService.criar(new PetRequest("Luna", "Gato", "Persa", LocalDate.of(2022, 1, 9), t1));

        LocalDate amanha = LocalDate.now().plusDays(1);
        agendamentoService.criar(new AgendamentoRequest(LocalDateTime.of(amanha, LocalTime.of(9, 0)), "Vacina antirrábica", "Trazer carteirinha", p1), null);
        agendamentoService.criar(new AgendamentoRequest(LocalDateTime.of(amanha, LocalTime.of(14, 30)), "Consulta de rotina", null, p2), null);
        agendamentoService.criar(new AgendamentoRequest(LocalDateTime.of(amanha.plusDays(2), LocalTime.of(10, 0)), "Retorno pós-cirúrgico", "Jejum de 8h", p3), null);
        agendamentoService.criar(new AgendamentoRequest(LocalDateTime.of(amanha.plusDays(5), LocalTime.of(16, 0)), "Banho e tosa", null, p1), null);

        usuarioService.criar(new UsuarioRequest("Administrador Geral", "admin@clinicavet.com", "Admin@123", "ADMIN", null, null, true));
        usuarioService.criar(new UsuarioRequest("Ana Atendente", "atendente@clinicavet.com", "Atend@123", "USUARIO", null, null, true));
        usuarioService.criar(new UsuarioRequest("Mariana Souza", "tutor@clinicavet.com", "Tutor@123", "TUTOR", null, t1, true));
        usuarioService.criar(new UsuarioRequest("Thor (Pet)", "pet@clinicavet.com", "Pet@1234", "PET", null, t1, true));

        log.info("Seed concluído. Login: admin@clinicavet.com / Admin@123");
    }
}
'@

Write-Host "done"
$total = (Get-ChildItem -Path (Join-Path (Get-Location) "backend\src") -Filter "*.java" -Recurse).Count
Write-Host "Total de arquivos .java em backend\src: $total"