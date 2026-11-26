package br.com.clinicavet.dto;
import java.time.LocalDateTime;
public record LogResponse(Long id, String entidade, Long entidadeId, String acao, String descricao, String usuarioEmail, LocalDateTime dataHora) {}