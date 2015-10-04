import 'dart:html';
import 'dart:math';
import 'dart:async';

Map<String, InputElement> inputs = new Map.fromIterable(
		document.getElementsByTagName('input'), 
		key: (InputElement ie) => ie.id, 
		value: (InputElement ie) => ie
);

Map<String, dynamic> values;

Random gen;
CanvasElement can = querySelector('#canvas');
CanvasRenderingContext2D ctx = can.context2D;

InputElement generateButton = querySelector('#gen');

int branches = 0;

void main() {				
	ctx
		..setStrokeColorRgb(0, 0, 0)
		..setFillColorRgb(0, 0, 0)
		..lineCap = 'round';
	
	generateButton.onClick.listen((Event e) {
		inputs.values.forEach((InputElement ie) => ie.disabled = true);

		values = new Map.fromIterable(inputs.keys, key: (String k) => k, value: (String k) => getFromInput(k));
				
		resetCanvas();
		var seed = values['seed'];
		querySelector('#oldSeed').innerHtml = seed.toString();
			
		gen = new Random(seed);
		recursiveGen(new Point(can.width ~/ 2, can.height), values['initDia'], 0);
	});
}

dynamic getFromInput(String s) {
	num NaN_0(num n) => n.isNaN ? 0 : n;
	
	var x = num.parse(inputs[s].value, (s) => num.parse('NaN')); // .valueAsNumber is broken in some browsers
	
	if(s == 'delay') {return new Duration(milliseconds: (NaN_0(x).abs()).round());}
	else if(s == 'seed') {return x.isNaN ? (new Random()).nextInt(10000) : x.round();}
	else {return NaN_0(x);}
}

void recursiveGen(Point start, num dia, num xCent) {
	if(dia == 0) { return; }
	branches++;

	num uniformCentered(num m) => gen.nextDouble() - 0.5 + m;
	
	num x(num scale) => start.x + (uniformCentered(xCent) * scale					 * values['lenDiaRatio']) * dia;
	num y(num scale) => start.y - (uniformCentered(scale + values['shift']) * values['lenDiaRatio']) * dia;
	
	var controls = new List.generate(3, 
		(int i) => new Point(x((i+1) / 3), y((i+1) / 3))
	);
	
	var itr = getBezier(start, controls[0], controls[1], controls[2]);
	itr.moveNext();
	var a = itr.current;
	
	new Timer.periodic(values['delay'], (Timer t) {
		if(itr.moveNext()) {			
			ctx
				..lineWidth = dia
				..beginPath()
				..moveTo(a.x, a.y)
				..lineTo(itr.current.x, itr.current.y)
				..stroke();
			
			a = itr.current;
		}
		else {
			t.cancel();
			branches--;

			ctx
				..beginPath()
				..moveTo(a.x, a.y + dia / 2)
				..arc(a.x, a.y, dia / 2, 0, 2 * PI)
				..fill();
			
			//Make recursive calls after this timer completes
			for(num i = values['branching']; i > 0; i--) {
				recursiveGen(controls[2], (dia * values['shrinkRatio']).floor(), values['spread'] * (i / (values['branching'] + 1) - 0.5));
			}
			
			if(branches == 0) { for(InputElement i in inputs.values) { i.disabled = false; } }
		}
	});
}

Iterator<Point> getBezier(Point start, Point a, Point b, Point end) {
	List points = [];
	
	Point evaluate(num t) => start * (pow(1-t, 3)) + a * (3 * t * pow(1-t, 2)) + b * (3 * (1-t) * pow(t, 2)) + end * (pow(t, 3));
	
	void calculateNext(Point s, Point e, num t1, num t2) {
		num tMid = (t1 + t2) / 2;
		Point mid = evaluate(tMid);
		
		num A2 = s.squaredDistanceTo(e);
		num B2 = s.squaredDistanceTo(mid);
		num C2 = e.squaredDistanceTo(mid);
		
		num theta = acos((B2 + C2 - A2) / 2 / sqrt(B2 * C2)); //Cosine law
		
		if(theta * 180 > 177 * PI) { points.add(s); } //If the angle between mid and the ends is wide enough
		else {
			calculateNext(s, mid, t1, tMid);
			calculateNext(mid, e, tMid, t2);
		}
	}
	
	calculateNext(start, end, 0, 1);
	points.add(end);
	return points.iterator;
}

void resetCanvas() {
	var pSize = can.parent.borderEdge;
	var sSize = can.parent.children[0].borderEdge;
	
	can..height = pSize.height - sSize.height
		 ..width = pSize.width;
	ctx.clearRect(0, 0, can.width, can.height);
}