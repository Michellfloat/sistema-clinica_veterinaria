package br.com.clinicavet.dto;
import br.com.clinicavet.model.StatusAgendamento;
import java.time.LocalDateTime;
/** Traz somente os dados necessÃ¡rios do tutor e do pet (sem CPF). */
public record AgendamentoResponse(Long id, LocalDateTime dataHora, String motivo, String observacoes,
                                  StatusAgendamento status, PetResumo pet, TutorResumo tutor) {
    public record PetResumo(Long id, String nome, String especie) {}
    public record TutorResumo(Long id, String nome, String telefone) {}
}