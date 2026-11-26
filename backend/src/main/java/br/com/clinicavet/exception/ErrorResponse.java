package br.com.clinicavet.exception;
import java.time.LocalDateTime;
import java.util.Map;
public record ErrorResponse(LocalDateTime timestamp, int status, String erro, String mensagem, Map<String, String> campos) {
    public static ErrorResponse of(int status, String erro, String mensagem) {
        return new ErrorResponse(LocalDateTime.now(), status, erro, mensagem, null);
    }
}