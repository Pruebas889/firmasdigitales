// app/javascript/controllers/reports_controller.js
import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto';


export default class extends Controller {
  static targets = ["startDateInput", "endDateInput", "userInput", "globalStats", "usersTable", "globalChart"]


  connect() {
    this.setInitialDates();
    this.fetchReportData();
  }


  setInitialDates() {
    const today = new Date().toISOString().slice(0, 10);
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    this.startDateInputTarget.value = thirtyDaysAgo;
    this.endDateInputTarget.value = today;
  }


  filterChanged() {
    this.fetchReportData();
  }


  async fetchReportData() {
    const startDate = this.startDateInputTarget.value;
    const endDate = this.endDateInputTarget.value;
    const userId = this.userInputTarget.value;


    const params = new URLSearchParams({
      start_date: startDate,
      end_date: endDate,
      user_id: userId
    }).toString();


    try {
      const response = await fetch(`/reports/data?${params}`);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();


      this.updateGlobalStats(data.global_stats);
      this.updateUsersTable(data.users_table_data);
      this.renderGlobalChart(data.global_stats);


    } catch (error) {
      console.error("Error fetching report data:", error);
      this.globalStatsTarget.innerHTML = "<p>Error al cargar las estadísticas.</p>";
      this.usersTableTarget.innerHTML = "<p>Error al cargar los datos de usuario.</p>";
    }
  }


  // --- Mapeo de nombres de estados para la UI ---
  stateMap = {
    completed_status: "Completados",
    sent_status: "Enviados",
    opened_status: "Abiertos",
    rejected_status: "Rechazados", // Usamos 'rejected_status' que creamos
    expired_status: "Expirados",
    partially_completed_status: "Parcialmente Completados",
    pending_status: "Pendientes", // Añadimos 'Pendientes'
  };


  updateGlobalStats(stats) {
    let statsHtml = `<h3>Total de Envíos: ${stats.total}</h3>`;
    for (const key in this.stateMap) {
      statsHtml += `<p>${this.stateMap[key]}: ${stats[key]}</p>`;
    }
    this.globalStatsTarget.innerHTML = statsHtml;
  }


  updateUsersTable(usersData) {
    let tableHtml = `
      <table class="reports-table">
        <thead>
          <tr>
            <th>Usuario</th>
            <th>Total</th>
    `;
    // Añadir encabezados de estado dinámicamente
    for (const key in this.stateMap) {
      tableHtml += `<th>${this.stateMap[key]}</th>`;
    }
    tableHtml += `
          </tr>
        </thead>
        <tbody>
    `;
   
    // Rellenar filas de datos
    for (const email in usersData) {
      const stats = usersData[email];
      tableHtml += `<tr><td>${email}</td><td>${stats.total}</td>`;
      for (const key in this.stateMap) {
        tableHtml += `<td>${stats[key]}</td>`;
      }
      tableHtml += `</tr>`;
    }
    tableHtml += `
        </tbody>
      </table>
    `;
    this.usersTableTarget.innerHTML = tableHtml;
  }


  // --- Gráficos (ejemplo con Chart.js) ---
  chart = null;


  renderGlobalChart(stats) {
    if (this.chart) {
      this.chart.destroy();
    }


    // Los labels del gráfico deben coincidir con los que se muestran en la UI
    const labels = Object.values(this.stateMap);
    const dataValues = Object.keys(this.stateMap).map(key => stats[key]);


    const backgroundColors = [
      'rgba(75, 192, 192, 0.6)',  // Completados (verde/azul)
      'rgba(54, 162, 235, 0.6)',   // Enviados (azul)
      'rgba(255, 206, 86, 0.6)',   // Abiertos (amarillo)
      'rgba(255, 99, 132, 0.6)',   // Rechazados (rojo)
      'rgba(153, 102, 255, 0.6)',  // Expirados (púrpura)
      'rgba(255, 159, 64, 0.6)',   // Parcialmente Completados (naranja)
      'rgba(201, 203, 207, 0.6)'   // Pendientes (gris)
    ];
   
    const colors = labels.map((_, index) => backgroundColors[index % backgroundColors.length]);


    this.chart = new Chart(this.globalChartTarget, {
      type: 'doughnut',
      data: {
        labels: labels,
        datasets: [{
          label: 'Conteo de Envíos por Estado',
          data: dataValues,
          backgroundColor: colors,
          borderColor: colors.map(c => c.replace('0.6', '1')),
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            position: 'top',
          },
          title: {
            display: true,
            text: 'Distribución de Envíos por Estado'
          }
        }
      }
    });
  }
}
