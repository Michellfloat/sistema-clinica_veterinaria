package br.com.clinicavet.service;

import br.com.clinicavet.dto.AgendamentoResponse;
import br.com.clinicavet.dto.DashboardResponse;
import br.com.clinicavet.mapper.AgendamentoMapper;
import br.com.clinicavet.model.StatusAgendamento;
import br.com.clinicavet.repository.AgendamentoRepository;
import br.com.clinicavet.repository.PetRepository;
import br.com.clinicavet.repository.TutorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DashboardService {

    private final TutorRepository tutorRepository;
    private final PetRepository petRepository;
    private final AgendamentoRepository agendamentoRepository;
    private final AgendamentoMapper agendamentoMapper;

    @Transactional(readOnly = true)
    public DashboardResponse resumo() {
        LocalDate hoje = LocalDate.now();
        long agendamentosHoje = agendamentoRepository.countByDataHoraBetweenAndStatusNot(
                hoje.atStartOfDay(), hoje.plusDays(1).atStartOfDay(), StatusAgendamento.CANCELADO);
        LocalDateTime agora = LocalDateTime.now();
        List<AgendamentoResponse> proximos = agendamentoRepository.listarOrdenados().stream()
                .filter(a -> a.getDataHora().isAfter(agora) && a.getStatus() != StatusAgendamento.CANCELADO)
                .limit(5).map(agendamentoMapper::toResponse).toList();
        return new DashboardResponse(tutorRepository.countByAtivoTrue(), petRepository.countByAtivoTrue(), agendamentosHoje, proximos);
    }
}