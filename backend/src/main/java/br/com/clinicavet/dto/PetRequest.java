package br.com.clinicavet.dto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
public record PetRequest(
        @NotBlank(message = "Informe o nome do pet.") @Size(max = 80) String nome,
        @NotBlank(message = "Informe a espÃ©cie.") @Size(max = 40) String especie,
        @Size(max = 60) String raca,
        @PastOrPresent(message = "A data de nascimento nÃ£o pode estar no futuro.") LocalDate dataNascimento,
        @NotNull(message = "Todo pet deve estar associado a um tutor.") Long tutorId) {}