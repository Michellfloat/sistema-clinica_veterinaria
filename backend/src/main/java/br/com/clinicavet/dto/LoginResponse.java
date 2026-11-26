package br.com.clinicavet.dto;
public record LoginResponse(String token, String tipo, long expiraEm, long expiraEmSegundos, UsuarioResponse usuario) {}