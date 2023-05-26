
// define a generic shepherd tour
// `scamp_tour` is a holding name that will be replaced by regular expression so multiple tours can be on the same page

const scamp_tour = new Shepherd.Tour({
  useModalOverlay: true,
  defaultStepOptions: {
    classes: '',
    scrollTo: true,
    exitOnEsc: true,
    cancelIcon: { enabled: true },
    modalOverlayOpeningRadius: 5,
    arrow: false
  }});

let tour_steps = new Array;
const buttons = [
    { text: 'Previous', action: scamp_tour.back },
    { text: 'Next', action: scamp_tour.next },
    { text: 'Exit', action: scamp_tour.cancel }];

for (let [id, params] of steps) {
  const s = new Shepherd.Step(scamp_tour, {
    id: id,
    text: params.text,
    title: params.title,
    attachTo: { element: document.getElementById(params.target), on: 'left' },
    buttons: tour_steps.length == 0 ? [buttons[1]] : [buttons[0], buttons[1]]});

  tour_steps.push(s);
}

scamp_tour.addSteps(tour_steps);
