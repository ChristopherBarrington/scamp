console.log('loaded shepherd-tours.js from static')

// define a generic shepherd tour
function make_default_tour(steps_json) {
	const tour = new Shepherd.Tour({
		useModalOverlay: false,
		defaultStepOptions: {
			classes: '',
			exitOnEsc: true,
			cancelIcon: {
				enabled: true },
			modalOverlayOpeningRadius: 4,
			arrow: true }});

	const steps = new Map(Object.entries(steps_json));
	const buttons = [{text: 'Back', action: tour.back},
	                 {text: 'Next', action: tour.next},
	                 {text: 'Exit', action: tour.cancel}];
	const scrollers = [{behavior: 'smooth', block: 'center'},
	                   {behavior: 'smooth', block: 'nearest'}]
	let tour_steps = new Array;

	for (let [id, params] of steps) {
		const s = new Shepherd.Step(tour, {
			id: id,
			text: params.text,
			title: params.title,
			attachTo: {
				element: document.getElementById(params.target),
				on: params.position || 'left' },
			buttons: tour_steps.length == 0 ? [buttons[1]] : (tour_steps.length+1 == steps.size ? [buttons[0], buttons[2]] : [buttons[0], buttons[1]]),
			scrollTo: tour_steps.length == 0 ? scrollers[0] : scrollers[1] });
		tour_steps.push(s);
	}

	tour.addSteps(tour_steps);
	return tour;
}
