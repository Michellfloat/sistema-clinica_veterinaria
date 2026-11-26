package br.com.clinicavet.dto;
public record TutorResponse(Long id, String nome, String cpfMascarado, String telefone, String email, String endereco, long totalPets) {}