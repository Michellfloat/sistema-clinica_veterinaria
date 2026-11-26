package br.com.clinicavet.service;

import br.com.clinicavet.dto.AgendamentoDataRequest;
import br.com.clinicavet.dto.AgendamentoRequest;
import br.com.clinicavet.dto.AgendamentoResponse;
import br.com.clinicavet.dto.AgendamentoStatusRequest;
import br.com.clinicavet.exception.BusinessException;
import br.com.clinicavet.exception.ConflictException;
import br.com.clinicavet.exception.NotFoundException;
import br.com.clinicavet.mapper.AgendamentoMapper;
import br.com.clinicavet.model.Agendamento;
import br.com.clinicavet.model.Pet;
import br.com.clinicavet.model.StatusAgendamento;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.repository.AgendamentoRepository;
import br.com.clinicavet.repository.PetRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AgendamentoService {

    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

    private final AgendamentoRepository agendamentoRepository;
    private final PetRepository petRepository;
    private final AgendamentoMapper mapper;
    private final LogService logService;

    /** Listagem ordenada por dia/hora do agendamento, com dados do tutor e do pet. */
    @Transactional(readOnly = true)
    public List<AgendamentoResponse> listar(Usuario usuario) {
        List<Agendamento> lista;
        if (PetService.somenteProprios(usuario)) {
            lista = usuario.getTutor() == null ? List.of() : agendamentoRepository.listarPorTutor(usuario.getTutor().getId());
        } else {
            lista = agendamentoRepository.listarOrdenados();
        }
        return lista.stream().map(mapper::toResponse).toList();
    }

    @Transactional
    public AgendamentoResponse criar(AgendamentoRequest req, Usuario responsavel) {
        Pet pet = petRepository.buscarAtivoPorId(req.petId()).orElseThrow(() -> new NotFoundException("Pet nÃ£o encontrado."));
        validarData(req.dataHora());
        validarConflito(pet.getId(), req.dataHora());

        Agendamento ag = Agendamento.builder().dataHora(req.dataHora()).motivo(req.motivo().trim())
                .observacoes(req.observacoes()).pet(pet).usuario(responsavel).status(StatusAgendamento.AGENDADO).build();
        ag = agendamentoRepository.save(ag);
        logService.agendamento(ag.getId(), "CRIACAO",
                "Agendamento criado para " + pet.getNome() + " em " + ag.getDataHora().format(FMT), null, ag.getDataHora());
        return mapper.toResponse(ag);
    }

    /** Atualiza somente a data/hora de um agendamento jÃ¡ cadastrado e registra no log_agendamento. */
    @Transactional
    public AgendamentoResponse atualizarData(Long id, AgendamentoDataRequest req) {
        Agendamento ag = obter(id);
        if (ag.getStatus() == StatusAgendamento.CANCELADO || ag.getStatus() == StatusAgendamento.CONCLUIDO) {
            throw new BusinessException("Agendamentos cancelados ou concluÃ­dos nÃ£o podem ser reagendados.");
        }
        validarData(req.dataHora());
        if (!req.dataHora().equals(ag.getDataHora())) validarConflito(ag.getPet().getId(), req.dataHora());

        LocalDateTime anterior = ag.getDataHora();
        ag.setDataHora(req.dataHora());
        ag = agendamentoRepository.save(ag);
        logService.agendamento(id, "REAGENDAMENTO",
                "Data alterada de " + anterior.format(FMT) + " para " + req.dataHora().format(FMT), anterior, req.dataHora());
        return mapper.toResponse(ag);
    }

    @Transactional
    public AgendamentoResponse atualizarStatus(Long id, AgendamentoStatusRequest req) {
        Agendamento ag = obter(id);
        StatusAgendamento anterior = ag.getStatus();
        ag.setStatus(req.status());
        ag = agendamentoRepository.save(ag);
        logService.agendamento(id, "STATUS", "Status alterado de " + anterior + " para " + req.status(), null, null);
        return mapper.toResponse(ag);
    }

    private Agendamento obter(Long id) {
        return agendamentoRepository.buscarPorId(id).orElseThrow(() -> new NotFoundException("Agendamento nÃ£o encontrado."));
    }

    private void validarData(LocalDateTime dataHora) {
        if (!dataHora.isAfter(LocalDateTime.now())) throw new BusinessException("Escolha uma data e hora futuras.");
    }

    private void validarConflito(Long petId, LocalDateTime dataHora) {
        if (agendamentoRepository.existsByPetIdAndDataHoraAndStatusNot(petId, dataHora, StatusAgendamento.CANCELADO)) {
            throw new ConflictException("Este pet jÃ¡ possui um agendamento nesse horÃ¡rio.");
        }
    }
}