function drawKillChart(dataset) {
    // adapt received data to chartjs
    let labels = [];
    let data = [];
    for (var i = 0; i < dataset.length; i++) {
        labels.push(dataset[i].label);
        data.push(dataset[i].data);
    }
    // update the chart
    var ctx = document.getElementById('kill_chart').getContext('2d');
    // https://www.chartjs.org/docs/latest/charts/bar.html
    var myChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: '# of Kills',
                data: data,
                backgroundColor: [
                    'rgba(255, 99, 132, 0.2)',
                    'rgba(54, 162, 235, 0.2)',
                    'rgba(255, 206, 86, 0.2)',
                    'rgba(75, 192, 192, 0.2)',
                    'rgba(153, 102, 255, 0.2)',
                    'rgba(255, 159, 64, 0.2)'
                ],
                borderColor: [
                    'rgba(255, 99, 132, 1)',
                    'rgba(54, 162, 235, 1)',
                    'rgba(255, 206, 86, 1)',
                    'rgba(75, 192, 192, 1)',
                    'rgba(153, 102, 255, 1)',
                    'rgba(255, 159, 64, 1)'
                ],
                borderWidth: 1
            }]
        },
        options: {
            scales: {
                yAxes: [{
                    ticks: {
                        beginAtZero: true
                    }
                }]
            },
            legend: {
                display: false
            },
            animation: {
                duration: 0
            }
        }
    });
}

// data sent by the server
let default_dataset = [
    {
        label: 'Red',
        data: 12
    },
    {
        label: 'Blue',
        data: 19
    },
    {
        label: 'Yellow',
        data: 3
    },
    {
        label: 'Green',
        data: 5
    },
    {
        label: 'Purple',
        data: 2
    },
    {
        label: 'Orange',
        data: 3
    },
];

drawKillChart(default_dataset);

// test refresh graph
// setInterval(() => {
//     console.log(default_dataset[0].data);
//     default_dataset[0].data++;
//     drawKillChart(default_dataset)
// }, 100);
