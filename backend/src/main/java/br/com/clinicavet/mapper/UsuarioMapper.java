package br.com.clinicavet.mapper;
import br.com.clinicavet.dto.UsuarioResponse;
import br.com.clinicavet.model.Usuario;
import org.springframework.stereotype.Component;
@Component
public class UsuarioMapper {
    public UsuarioResponse toResponse(Usuario u) {
        return new UsuarioResponse(u.getId(), u.getNome(), u.getEmail(), u.getFotoUrl(), u.getPerfil().getNome(),
                u.getAtivo(), u.getTutor() != null ? u.getTutor().getId() : null);
    }
}