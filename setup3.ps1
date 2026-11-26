$base = if (Test-Path "clinica-veterinaria/backend/src/main/java/br/com/clinicavet") { "clinica-veterinaria/backend/src/main/java/br/com/clinicavet" } else { "backend/src/main/java/br/com/clinicavet" }
Set-Location $base
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
function Write-File($path, $content) { [System.IO.File]::WriteAllText((Join-Path (Get-Location).ProviderPath $path), $content, $utf8NoBom) }
Write-File "util/CpfUtil.java" @'
package br.com.clinicavet.util;
/** Utilitários de CPF: limpeza, validação dos dígitos verificadores e máscara (LGPD). */
public final class CpfUtil {
    private CpfUtil() {}
    public static String limpar(String cpf) {
        return cpf == null ? "" : cpf.replaceAll("\\D", "");
    }
    public static boolean valido(String cpf) {
        String n = limpar(cpf);
        if (n.length() != 11 || n.chars().distinct().count() == 1) return false;
        return digito(n, 9) == n.charAt(9) - '0' && digito(n, 10) == n.charAt(10) - '0';
    }
    private static int digito(String n, int tamanho) {
        int soma = 0;
        for (int i = 0; i < tamanho; i++) {
            soma += (n.charAt(i) - '0') * (tamanho + 1 - i);
        }
        int resto = (soma * 10) % 11;
        return resto == 10 ? 0 : resto;
    }
    /** Exibe apenas o miolo: ***.456.789-** */
    public static String mascarar(String cpf) {
        String n = limpar(cpf);
        if (n.length() != 11) return "***.***.***-**";
        return "***." + n.substring(3, 6) + "." + n.substring(6, 9) + "-**";
    }
}
'@
foreach ($N in @("NotFoundException","ConflictException","BusinessException")) {
    Write-File "exception/$N.java" @"
package br.com.clinicavet.exception;
public class $N extends RuntimeException {
    public $N(String mensagem) { super(mensagem); }
}
"@
}
Write-File "exception/ErrorResponse.java" @'
package br.com.clinicavet.exception;
import java.time.LocalDateTime;
import java.util.Map;
public record ErrorResponse(LocalDateTime timestamp, int status, String erro, String mensagem, Map<String, String> campos) {
    public static ErrorResponse of(int status, String erro, String mensagem) {
        return new ErrorResponse(LocalDateTime.now(), status, erro, mensagem, null);
    }
}
'@
Write-File "exception/GlobalExceptionHandler.java" @'
package br.com.clinicavet.exception;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {
    private ResponseEntity<ErrorResponse> resposta(HttpStatus status, String mensagem) {
        return ResponseEntity.status(status).body(ErrorResponse.of(status.value(), status.getReasonPhrase(), mensagem));
    }
    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<ErrorResponse> naoEncontrado(NotFoundException e) {
        return resposta(HttpStatus.NOT_FOUND, e.getMessage());
    }
    @ExceptionHandler(ConflictException.class)
    public ResponseEntity<ErrorResponse> conflito(ConflictException e) {
        return resposta(HttpStatus.CONFLICT, e.getMessage());
    }
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ErrorResponse> negocio(BusinessException e) {
        return resposta(HttpStatus.BAD_REQUEST, e.getMessage());
    }
    @ExceptionHandler({BadCredentialsException.class, DisabledException.class})
    public ResponseEntity<ErrorResponse> credenciais(Exception e) {
        // Mensagem genérica: não revela se o e-mail existe (OWASP)
        return resposta(HttpStatus.UNAUTHORIZED, "E-mail ou senha inválidos.");
    }
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> negado(AccessDeniedException e) {
        return resposta(HttpStatus.FORBIDDEN, "Você não tem permissão para executar esta ação.");
    }
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> validacao(MethodArgumentNotValidException e) {
        Map<String, String> campos = new LinkedHashMap<>();
        e.getBindingResult().getFieldErrors().forEach(f -> campos.putIfAbsent(f.getField(), f.getDefaultMessage()));
        ErrorResponse body = new ErrorResponse(LocalDateTime.now(), 400, "Bad Request",
                "Há campos inválidos. Corrija e tente novamente.", campos);
        return ResponseEntity.badRequest().body(body);
    }
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> jsonInvalido(HttpMessageNotReadableException e) {
        return resposta(HttpStatus.BAD_REQUEST, "Corpo da requisição inválido ou mal formatado.");
    }
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ErrorResponse> integridade(DataIntegrityViolationException e) {
        log.warn("Violação de integridade: {}", e.getMostSpecificCause().getMessage());
        return resposta(HttpStatus.CONFLICT, "Operação viola uma regra de integridade dos dados (registro duplicado ou em uso).");
    }
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> generico(Exception e) {
        log.error("Erro inesperado", e);
        return resposta(HttpStatus.INTERNAL_SERVER_ERROR, "Erro interno. Tente novamente em instantes.");
    }
}
'@
Write-File "dto/LoginRequest.java" @'
package br.com.clinicavet.dto;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
public record LoginRequest(
        @NotBlank(message = "Informe o e-mail.") @Email(message = "E-mail inválido.") String email,
        @NotBlank(message = "Informe a senha.") String senha) {}
'@
Write-File "dto/UsuarioResponse.java" @'
package br.com.clinicavet.dto;
public record UsuarioResponse(Long id, String nome, String email, String fotoUrl, String perfil, Boolean ativo, Long tutorId) {}
'@
Write-File "dto/LoginResponse.java" @'
package br.com.clinicavet.dto;
public record LoginResponse(String token, String tipo, long expiraEm, long expiraEmSegundos, UsuarioResponse usuario) {}
'@
Write-File "dto/UsuarioRequest.java" @'
package br.com.clinicavet.dto;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
public record UsuarioRequest(
        @NotBlank(message = "Informe o nome.") @Size(max = 120) String nome,
        @NotBlank(message = "Informe o e-mail.") @Email(message = "E-mail inválido.") String email,
        @Size(min = 6, max = 60, message = "A senha deve ter entre 6 e 60 caracteres.") String senha,
        @NotBlank(message = "Informe o perfil.") String perfil,
        @Size(max = 255) String fotoUrl,
        Long tutorId,
        Boolean ativo) {}
'@
Write-File "dto/TutorRequest.java" @'
package br.com.clinicavet.dto;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
/** O CPF é obrigatório na criação e opcional na edição (só é regravado se enviado). */
public record TutorRequest(
        @NotBlank(message = "Informe o nome do tutor.") @Size(max = 120) String nome,
        String cpf,
        @NotBlank(message = "Informe o telefone.") @Size(max = 20) String telefone,
        @NotBlank(message = "Informe o e-mail.") @Email(message = "E-mail inválido.") @Size(max = 120) String email,
        @Size(max = 255) String endereco) {}
'@
Write-File "dto/TutorResponse.java" @'
package br.com.clinicavet.dto;
public record TutorResponse(Long id, String nome, String cpfMascarado, String telefone, String email, String endereco, long totalPets) {}
'@
Write-File "dto/PetRequest.java" @'
package br.com.clinicavet.dto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
public record PetRequest(
        @NotBlank(message = "Informe o nome do pet.") @Size(max = 80) String nome,
        @NotBlank(message = "Informe a espécie.") @Size(max = 40) String especie,
        @Size(max = 60) String raca,
        @PastOrPresent(message = "A data de nascimento não pode estar no futuro.") LocalDate dataNascimento,
        @NotNull(message = "Todo pet deve estar associado a um tutor.") Long tutorId) {}
'@
Write-File "dto/PetResponse.java" @'
package br.com.clinicavet.dto;
import java.time.LocalDate;
public record PetResponse(Long id, String nome, String especie, String raca, LocalDate dataNascimento, Long tutorId, String tutorNome) {}
'@
Write-File "dto/AgendamentoRequest.java" @'
package br.com.clinicavet.dto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDateTime;
public record AgendamentoRequest(
        @NotNull(message = "Informe a data e hora.") LocalDateTime dataHora,
        @NotBlank(message = "Informe o motivo da consulta.") @Size(max = 160) String motivo,
        @Size(max = 255) String observacoes,
        @NotNull(message = "Selecione o pet.") Long petId) {}
'@
Write-File "dto/AgendamentoDataRequest.java" @'
package br.com.clinicavet.dto;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDateTime;
public record AgendamentoDataRequest(@NotNull(message = "Informe a nova data e hora.") LocalDateTime dataHora) {}
'@
Write-File "dto/AgendamentoStatusRequest.java" @'
package br.com.clinicavet.dto;
import br.com.clinicavet.model.StatusAgendamento;
import jakarta.validation.constraints.NotNull;
public record AgendamentoStatusRequest(@NotNull(message = "Informe o status.") StatusAgendamento status) {}
'@
Write-File "dto/AgendamentoResponse.java" @'
package br.com.clinicavet.dto;
import br.com.clinicavet.model.StatusAgendamento;
import java.time.LocalDateTime;
/** Traz somente os dados necessários do tutor e do pet (sem CPF). */
public record AgendamentoResponse(Long id, LocalDateTime dataHora, String motivo, String observacoes,
                                  StatusAgendamento status, PetResumo pet, TutorResumo tutor) {
    public record PetResumo(Long id, String nome, String especie) {}
    public record TutorResumo(Long id, String nome, String telefone) {}
}
'@
Write-File "dto/LogResponse.java" @'
package br.com.clinicavet.dto;
import java.time.LocalDateTime;
public record LogResponse(Long id, String entidade, Long entidadeId, String acao, String descricao, String usuarioEmail, LocalDateTime dataHora) {}
'@
Write-File "dto/DashboardResponse.java" @'
package br.com.clinicavet.dto;
import java.util.List;
public record DashboardResponse(long totalTutores, long totalPets, long agendamentosHoje, List<AgendamentoResponse> proximos) {}
'@
Write-File "mapper/UsuarioMapper.java" @'
package br.com.clinicavet.mapper;
import br.com.clinicavet.dto.UsuarioResponse;
import br.com.clinicavet.model.Usuario;
import org.springframework.stereotype.Component;
@Component
public class UsuarioMapper {
    public UsuarioResponse toResponse(Usuario u) {
        return new UsuarioResponse(u.getId(), u.getNome(), u.getEmail(), u.getFotoUrl(), u.getPerfil().getNome(),
                u.getAtivo(), u.getTutor() != null ? u.getTutor().getId() : null);
    }
}
'@
Write-File "mapper/TutorMapper.java" @'
package br.com.clinicavet.mapper;
import br.com.clinicavet.dto.TutorResponse;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.service.CryptoService;
import br.com.clinicavet.util.CpfUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
@Component
@RequiredArgsConstructor
public class TutorMapper {
    private final CryptoService crypto;
    /** O CPF nunca sai da API em texto puro: apenas mascarado. */
    public TutorResponse toResponse(Tutor t, long totalPets) {
        String cpfMascarado = CpfUtil.mascarar(crypto.decifrar(t.getCpfCriptografado()));
        return new TutorResponse(t.getId(), t.getNome(), cpfMascarado, t.getTelefone(), t.getEmail(), t.getEndereco(), totalPets);
    }
}
'@
Write-File "mapper/PetMapper.java" @'
package br.com.clinicavet.mapper;
import br.com.clinicavet.dto.PetResponse;
import br.com.clinicavet.model.Pet;
import org.springframework.stereotype.Component;
@Component
public class PetMapper {
    public PetResponse toResponse(Pet p) {
        return new PetResponse(p.getId(), p.getNome(), p.getEspecie(), p.getRaca(), p.getDataNascimento(),
                p.getTutor().getId(), p.getTutor().getNome());
    }
}
'@
Write-File "mapper/AgendamentoMapper.java" @'
package br.com.clinicavet.mapper;
import br.com.clinicavet.dto.AgendamentoResponse;
import br.com.clinicavet.model.Agendamento;
import org.springframework.stereotype.Component;
@Component
public class AgendamentoMapper {
    public AgendamentoResponse toResponse(Agendamento a) {
        var pet = a.getPet();
        var tutor = pet.getTutor();
        return new AgendamentoResponse(a.getId(), a.getDataHora(), a.getMotivo(), a.getObservacoes(), a.getStatus(),
                new AgendamentoResponse.PetResumo(pet.getId(), pet.getNome(), pet.getEspecie()),
                new AgendamentoResponse.TutorResumo(tutor.getId(), tutor.getNome(), tutor.getTelefone()));
    }
}
'@
Write-Output "done"