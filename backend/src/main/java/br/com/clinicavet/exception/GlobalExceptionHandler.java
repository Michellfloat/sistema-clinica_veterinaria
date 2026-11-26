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
        // Mensagem genÃ©rica: nÃ£o revela se o e-mail existe (OWASP)
        return resposta(HttpStatus.UNAUTHORIZED, "E-mail ou senha invÃ¡lidos.");
    }
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> negado(AccessDeniedException e) {
        return resposta(HttpStatus.FORBIDDEN, "VocÃª nÃ£o tem permissÃ£o para executar esta aÃ§Ã£o.");
    }
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> validacao(MethodArgumentNotValidException e) {
        Map<String, String> campos = new LinkedHashMap<>();
        e.getBindingResult().getFieldErrors().forEach(f -> campos.putIfAbsent(f.getField(), f.getDefaultMessage()));
        ErrorResponse body = new ErrorResponse(LocalDateTime.now(), 400, "Bad Request",
                "HÃ¡ campos invÃ¡lidos. Corrija e tente novamente.", campos);
        return ResponseEntity.badRequest().body(body);
    }
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> jsonInvalido(HttpMessageNotReadableException e) {
        return resposta(HttpStatus.BAD_REQUEST, "Corpo da requisiÃ§Ã£o invÃ¡lido ou mal formatado.");
    }
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ErrorResponse> integridade(DataIntegrityViolationException e) {
        log.warn("ViolaÃ§Ã£o de integridade: {}", e.getMostSpecificCause().getMessage());
        return resposta(HttpStatus.CONFLICT, "OperaÃ§Ã£o viola uma regra de integridade dos dados (registro duplicado ou em uso).");
    }
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> generico(Exception e) {
        log.error("Erro inesperado", e);
        return resposta(HttpStatus.INTERNAL_SERVER_ERROR, "Erro interno. Tente novamente em instantes.");
    }
}