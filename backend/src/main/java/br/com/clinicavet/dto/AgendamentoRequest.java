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