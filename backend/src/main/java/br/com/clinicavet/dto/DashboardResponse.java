package br.com.clinicavet.dto;
import java.util.List;
public record DashboardResponse(long totalTutores, long totalPets, long agendamentosHoje, List<AgendamentoResponse> proximos) {}