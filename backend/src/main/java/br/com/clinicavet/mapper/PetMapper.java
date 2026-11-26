package br.com.clinicavet.mapper;
import br.com.clinicavet.dto.PetResponse;
import br.com.clinicavet.model.Pet;
import org.springframework.stereotype.Component;
@Component
public class PetMapper {
    public PetResponse toResponse(Pet p) {
        return new PetResponse(p.getId(), p.getNome(), p.getEspecie(), p.getRaca(), p.getDataNascimento(),
                p.getTutor().getId(), p.getTutor().getNome());
    }
}