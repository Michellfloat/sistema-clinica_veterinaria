package br.com.clinicavet.mapper;
import br.com.clinicavet.dto.TutorResponse;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.service.CryptoService;
import br.com.clinicavet.util.CpfUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
@Component
@RequiredArgsConstructor
public class TutorMapper {
    private final CryptoService crypto;
    /** O CPF nunca sai da API em texto puro: apenas mascarado. */
    public TutorResponse toResponse(Tutor t, long totalPets) {
        String cpfMascarado = CpfUtil.mascarar(crypto.decifrar(t.getCpfCriptografado()));
        return new TutorResponse(t.getId(), t.getNome(), cpfMascarado, t.getTelefone(), t.getEmail(), t.getEndereco(), totalPets);
    }
}