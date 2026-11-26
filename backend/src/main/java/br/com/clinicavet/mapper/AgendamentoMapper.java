package br.com.clinicavet.mapper;
import br.com.clinicavet.dto.AgendamentoResponse;
import br.com.clinicavet.model.Agendamento;
import org.springframework.stereotype.Component;
@Component
public class AgendamentoMapper {
    public AgendamentoResponse toResponse(Agendamento a) {
        var pet = a.getPet();
        var tutor = pet.getTutor();
        return new AgendamentoResponse(a.getId(), a.getDataHora(), a.getMotivo(), a.getObservacoes(), a.getStatus(),
                new AgendamentoResponse.PetResumo(pet.getId(), pet.getNome(), pet.getEspecie()),
                new AgendamentoResponse.TutorResumo(tutor.getId(), tutor.getNome(), tutor.getTelefone()));
    }
}