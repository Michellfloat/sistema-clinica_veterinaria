package br.com.clinicavet.dto;
import br.com.clinicavet.model.StatusAgendamento;
import jakarta.validation.constraints.NotNull;
public record AgendamentoStatusRequest(@NotNull(message = "Informe o status.") StatusAgendamento status) {}