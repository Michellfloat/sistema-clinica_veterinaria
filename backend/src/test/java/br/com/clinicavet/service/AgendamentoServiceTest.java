package br.com.clinicavet.service;

import br.com.clinicavet.dto.AgendamentoDataRequest;
import br.com.clinicavet.dto.AgendamentoRequest;
import br.com.clinicavet.dto.AgendamentoResponse;
import br.com.clinicavet.exception.BusinessException;
import br.com.clinicavet.exception.ConflictException;
import br.com.clinicavet.mapper.AgendamentoMapper;
import br.com.clinicavet.model.Agendamento;
import br.com.clinicavet.model.Pet;
import br.com.clinicavet.model.StatusAgendamento;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.repository.AgendamentoRepository;
import br.com.clinicavet.repository.PetRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AgendamentoServiceTest {

    @Mock AgendamentoRepository agendamentoRepository;
    @Mock PetRepository petRepository;
    @Mock LogService logService;
    private AgendamentoService service;

    private final Tutor tutor = Tutor.builder().id(1L).nome("Mariana").telefone("7199").build();
    private final Pet pet = Pet.builder().id(10L).nome("Thor").especie("CÃ£o").tutor(tutor).build();

    @BeforeEach
    void setUp() {
        service = new AgendamentoService(agendamentoRepository, petRepository, new AgendamentoMapper(), logService);
    }

    private Agendamento agendamento(LocalDateTime data, StatusAgendamento status) {
        return Agendamento.builder().id(1L).dataHora(data).motivo("Vacina").status(status).pet(pet).build();
    }

    @Test
    void atualizarData_salvaNovaDataERegistraLog() {
        LocalDateTime antiga = LocalDateTime.now().plusDays(2);
        LocalDateTime nova = LocalDateTime.now().plusDays(5);
        when(agendamentoRepository.buscarPorId(1L)).thenReturn(Optional.of(agendamento(antiga, StatusAgendamento.AGENDADO)));
        when(agendamentoRepository.existsByPetIdAndDataHoraAndStatusNot(10L, nova, StatusAgendamento.CANCELADO)).thenReturn(false);
        when(agendamentoRepository.save(any(Agendamento.class))).thenAnswer(inv -> inv.getArgument(0));

        AgendamentoResponse resp = service.atualizarData(1L, new AgendamentoDataRequest(nova));

        assertEquals(nova, resp.dataHora());
        verify(logService).agendamento(eq(1L), eq("REAGENDAMENTO"), anyString(), eq(antiga), eq(nova));
    }

    @Test
    void atualizarData_comDataNoPassado_lancaBusinessException() {
        when(agendamentoRepository.buscarPorId(1L)).thenReturn(Optional.of(agendamento(LocalDateTime.now().plusDays(2), StatusAgendamento.AGENDADO)));
        assertThrows(BusinessException.class,
                () -> service.atualizarData(1L, new AgendamentoDataRequest(LocalDateTime.now().minusDays(1))));
        verify(agendamentoRepository, never()).save(any());
    }

    @Test
    void atualizarData_agendamentoCancelado_naoPermiteReagendar() {
        when(agendamentoRepository.buscarPorId(1L)).thenReturn(Optional.of(agendamento(LocalDateTime.now().plusDays(2), StatusAgendamento.CANCELADO)));
        assertThrows(BusinessException.class,
                () -> service.atualizarData(1L, new AgendamentoDataRequest(LocalDateTime.now().plusDays(3))));
    }

    @Test
    void criar_comConflitoDeHorarioParaOMesmoPet_lancaConflictException() {
        LocalDateTime data = LocalDateTime.now().plusDays(1);
        when(petRepository.buscarAtivoPorId(10L)).thenReturn(Optional.of(pet));
        when(agendamentoRepository.existsByPetIdAndDataHoraAndStatusNot(10L, data, StatusAgendamento.CANCELADO)).thenReturn(true);
        assertThrows(ConflictException.class,
                () -> service.criar(new AgendamentoRequest(data, "Consulta", null, 10L), null));
        verify(agendamentoRepository, never()).save(any());
    }
}