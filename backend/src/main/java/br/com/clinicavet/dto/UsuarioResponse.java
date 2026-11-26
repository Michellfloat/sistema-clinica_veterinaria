package br.com.clinicavet.dto;
public record UsuarioResponse(Long id, String nome, String email, String fotoUrl, String perfil, Boolean ativo, Long tutorId) {}