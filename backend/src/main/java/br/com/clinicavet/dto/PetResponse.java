package br.com.clinicavet.dto;
import java.time.LocalDate;
public record PetResponse(Long id, String nome, String especie, String raca, LocalDate dataNascimento, Long tutorId, String tutorNome) {}