package br.com.clinicavet.service;

import br.com.clinicavet.dto.LogResponse;
import br.com.clinicavet.model.*;
import br.com.clinicavet.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/** Registra o histÃ³rico de atualizaÃ§Ãµes de cada funcionalidade (tabelas log_*). */
@Service
@RequiredArgsConstructor
public class LogService {

    private final LogTutorRepository logTutorRepository;
    private final LogPetRepository logPetRepository;
    private final LogAgendamentoRepository logAgendamentoRepository;
    private final LogUsuarioRepository logUsuarioRepository;

    private String emailAtual() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        if (a == null || !a.isAuthenticated() || a instanceof AnonymousAuthenticationToken) return "SISTEMA";
        return a.getName();
    }

    public void tutor(Long tutorId, String acao, String descricao) {
        logTutorRepository.save(LogTutor.builder().tutorId(tutorId).acao(acao).descricao(cortar(descricao))
                .usuarioEmail(emailAtual()).dataHora(LocalDateTime.now()).build());
    }

    public void pet(Long petId, String acao, String descricao) {
        logPetRepository.save(LogPet.builder().petId(petId).acao(acao).descricao(cortar(descricao))
                .usuarioEmail(emailAtual()).dataHora(LocalDateTime.now()).build());
    }

    public void agendamento(Long id, String acao, String descricao, LocalDateTime anterior, LocalDateTime nova) {
        logAgendamentoRepository.save(LogAgendamento.builder().agendamentoId(id).acao(acao).descricao(cortar(descricao))
                .dataAnterior(anterior).dataNova(nova).usuarioEmail(emailAtual()).dataHora(LocalDateTime.now()).build());
    }

    public void usuario(Long usuarioId, String acao, String descricao, String autorEmail) {
        logUsuarioRepository.save(LogUsuario.builder().usuarioId(usuarioId).acao(acao).descricao(cortar(descricao))
                .usuarioEmail(autorEmail != null ? autorEmail : emailAtual()).dataHora(LocalDateTime.now()).build());
    }

    @Transactional(readOnly = true)
    public List<LogResponse> listarTodos() {
        List<LogResponse> todos = new ArrayList<>();
        logTutorRepository.findTop100ByOrderByDataHoraDesc().forEach(l ->
                todos.add(new LogResponse(l.getId(), "TUTOR", l.getTutorId(), l.getAcao(), l.getDescricao(), l.getUsuarioEmail(), l.getDataHora())));
        logPetRepository.findTop100ByOrderByDataHoraDesc().forEach(l ->
                todos.add(new LogResponse(l.getId(), "PET", l.getPetId(), l.getAcao(), l.getDescricao(), l.getUsuarioEmail(), l.getDataHora())));
        logAgendamentoRepository.findTop100ByOrderByDataHoraDesc().forEach(l ->
                todos.add(new LogResponse(l.getId(), "AGENDAMENTO", l.getAgendamentoId(), l.getAcao(), l.getDescricao(), l.getUsuarioEmail(), l.getDataHora())));
        logUsuarioRepository.findTop100ByOrderByDataHoraDesc().forEach(l ->
                todos.add(new LogResponse(l.getId(), "USUARIO", l.getUsuarioId(), l.getAcao(), l.getDescricao(), l.getUsuarioEmail(), l.getDataHora())));
        todos.sort(Comparator.comparing(LogResponse::dataHora).reversed());
        return todos.size() > 100 ? todos.subList(0, 100) : todos;
    }

    private String cortar(String s) {
        return s != null && s.length() > 500 ? s.substring(0, 497) + "..." : s;
    }
}