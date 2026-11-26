package br.com.clinicavet.dto;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDateTime;
public record AgendamentoDataRequest(@NotNull(message = "Informe a nova data e hora.") LocalDateTime dataHora) {}