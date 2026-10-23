import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';

// Same source->three mapping Dennys uses (source is Z-up): (x, z, -y)
const convert = p => new THREE.Vector3(p[0], p[2], -p[1]);
const MODEL = '../building-review/assets/pursuit-building.glb';

// Combined walking path (source coords, feet on floor), stitched from scene.json routes:
// street -> ramp -> elevator (rises) -> upper landing/reception -> through double doors -> classroom.
const PATH = [
  [0,-7,0],[0,-4.5,0],[0,-2.6,0],[0,-2,0],                         // street
  [2.35,-2.1,0],[2.35,4.8,0.85],[2.35,8,0.85],[2.35,12.1,0.85],[-0.95,12.1,0.85], // ramp -> elevator (ground)
  [-0.95,12.1,5.05],                                               // elevator up to 2nd floor
  [2.5,12.1,5.05],[3.3,12.8,5.05],[5.25,12.8,5.05],[8.3,12.8,5.05],[10.4,12.8,5.05], // landing / reception
  [12.1,9.72,5.05],[13.3,9.72,5.05],[15.4,9.72,5.05],[18.56,9.72,5.05],[18.56,7.0,5.05],[18.56,2.0,5.05] // doors -> classroom
];
// label for each node index
const LABELS = ['Street','Street','Street','Street','Up the ramp','Up the ramp','Up the ramp','Up the ramp','Elevator',
  'Elevator','Second-floor landing','Reception','Reception','Reception','Reception',
  'Through the double doors','Through the double doors','Through the double doors','Entering the classroom','In the classroom','In the classroom'];
const JUMP = { start:0, elevator:8, classroom:PATH.length-1 };

// Build converted points + cumulative arc length for a constant-speed walk.
const pts = PATH.map(convert);
const cum = [0];
for(let i=1;i<pts.length;i++) cum.push(cum[i-1] + pts[i].distanceTo(pts[i-1]));
const TOTAL = cum[cum.length-1];

function at(s){ // position + segment index + tangent at arc length s
  s = Math.max(0, Math.min(TOTAL, s));
  let i=1; while(i<cum.length-1 && cum[i] < s) i++;
  const a=pts[i-1], b=pts[i];
  const segLen = Math.max(1e-6, cum[i]-cum[i-1]);
  const f = (s-cum[i-1])/segLen;
  const pos = a.clone().lerp(b, f);
  const tan = b.clone().sub(a).normalize();
  return {pos, tan, seg:i-1, isVertical: Math.abs(b.y-a.y) > 0.6*a.distanceTo(b)};
}
function nodeArc(idx){ return cum[Math.max(0,Math.min(cum.length-1,idx))]; }

// ---------- three setup ----------
const canvas = document.getElementById('view');
const renderer = new THREE.WebGLRenderer({canvas, antialias:true});
renderer.setPixelRatio(Math.min(2, devicePixelRatio||1));
const scene = new THREE.Scene();
scene.background = new THREE.Color(0xaeb6c6);
scene.fog = new THREE.Fog(0xaeb6c6, 40, 120);
const camera = new THREE.PerspectiveCamera(55, 1, 0.03, 300);

scene.add(new THREE.HemisphereLight(0xffffff, 0xc4cad1, 2.0));
const sun = new THREE.DirectionalLight(0xffffff, 2.2); sun.position.set(-15,30,18); scene.add(sun);
const fill = new THREE.DirectionalLight(0xdcecff, 1.1); fill.position.set(20,10,-15); scene.add(fill);

// ---------- student avatar ----------
function buildStudent(){
  const g = new THREE.Group();
  const skin = new THREE.MeshStandardMaterial({color:0xf1c9a5, roughness:.8});
  const shirt = new THREE.MeshStandardMaterial({color:0x37e1ff, roughness:.6, metalness:.05});
  const pants = new THREE.MeshStandardMaterial({color:0x26407a, roughness:.8});
  const pack = new THREE.MeshStandardMaterial({color:0xffd24a, roughness:.7});
  const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.28,0.6,4,10), shirt); body.position.y=1.05; g.add(body);
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.22,18,16), skin); head.position.y=1.62; g.add(head);
  const bag = new THREE.Mesh(new THREE.BoxGeometry(0.42,0.5,0.22), pack); bag.position.set(0,1.1,-0.28); g.add(bag);
  const legL = new THREE.Mesh(new THREE.CapsuleGeometry(0.12,0.5,3,8), pants); legL.position.set(-0.14,0.45,0); g.add(legL);
  const legR = legL.clone(); legR.position.x=0.14; g.add(legR);
  const armL = new THREE.Mesh(new THREE.CapsuleGeometry(0.09,0.45,3,8), shirt); armL.position.set(-0.4,1.05,0); g.add(armL);
  const armR = armL.clone(); armR.position.x=0.4; g.add(armR);
  g.userData={legL,legR,armL,armR};
  return g;
}
const student = buildStudent(); scene.add(student);

// ---------- follow-camera (sits behind the student's heading) ----------
let camOffset = 0, pitch = 0.3, dist = 5.5, heading = Math.PI;
function placeCamera(head){
  const camYaw = heading + Math.PI + camOffset;   // behind the student
  const cp = Math.cos(pitch);
  camera.position.set(
    head.x + dist*Math.sin(camYaw)*cp,
    head.y + dist*Math.sin(pitch),
    head.z + dist*Math.cos(camYaw)*cp
  );
  camera.lookAt(head);
}
// drag to look around
let drag=false, lx=0, ly=0;
canvas.addEventListener('pointerdown',e=>{drag=true;lx=e.clientX;ly=e.clientY;});
addEventListener('pointermove',e=>{ if(!drag)return; camOffset-=(e.clientX-lx)*0.006; pitch=Math.max(-0.15,Math.min(1.1,pitch+(e.clientY-ly)*0.006)); lx=e.clientX; ly=e.clientY; });
addEventListener('pointerup',()=>drag=false);
canvas.addEventListener('wheel',e=>{ dist=Math.max(2.5,Math.min(16,dist+Math.sign(e.deltaY)*0.6)); e.preventDefault(); },{passive:false});

// ---------- input ----------
const keys={};
addEventListener('keydown',e=>{ keys[e.key.toLowerCase()]=true; if(e.key.startsWith('Arrow'))e.preventDefault(); });
addEventListener('keyup',e=>{ keys[e.key.toLowerCase()]=false; });
let press={fwd:0,back:0,left:0,right:0};
document.querySelectorAll('[data-move]').forEach(btn=>{
  const k=btn.dataset.move;
  const on=e=>{e.preventDefault(); press[k]=1; btn.classList.add('on'); ensureAudio();};
  const off=e=>{e.preventDefault(); press[k]=0; btn.classList.remove('on');};
  btn.addEventListener('pointerdown',on); btn.addEventListener('pointerup',off);
  btn.addEventListener('pointerleave',off); btn.addEventListener('pointercancel',off);
});
function wantFwd(){ return press.fwd||keys['arrowup']||keys['w']; }
function wantBack(){ return press.back||keys['arrowdown']||keys['s']; }
function wantLeft(){ return press.left||keys['arrowleft']||keys['a']; }
function wantRight(){ return press.right||keys['arrowright']||keys['d']; }

document.querySelectorAll('[data-jump]').forEach(b=> b.addEventListener('click',()=>{ ensureAudio(); s = nodeArc(JUMP[b.dataset.jump]); }));

// ---------- footsteps (WebAudio) ----------
let actx=null, muted=false, stepClock=0;
function ensureAudio(){ try{ if(!actx) actx=new (window.AudioContext||window.webkitAudioContext)(); if(actx.state==='suspended') actx.resume(); }catch(e){} }
function footstep(){ if(!actx||muted) return;
  const t=actx.currentTime, len=Math.floor(0.08*actx.sampleRate);
  const buf=actx.createBuffer(1,len,actx.sampleRate), d=buf.getChannelData(0);
  for(let i=0;i<len;i++) d[i]=(Math.random()*2-1)*Math.pow(1-i/len,3);
  const src=actx.createBufferSource(); src.buffer=buf;
  const bp=actx.createBiquadFilter(); bp.type='bandpass'; bp.frequency.value=170+Math.random()*70; bp.Q.value=0.8;
  const g=actx.createGain(); g.gain.value=0.45;
  src.connect(bp); bp.connect(g); g.connect(actx.destination); src.start(t);
}
document.getElementById('mute').addEventListener('click',e=>{ muted=!muted; e.target.textContent=muted?'🔇 Muted':'🔊 Sound'; if(!muted) ensureAudio(); });

// ---------- walk state ----------
let s = 0;               // arc length position
const SPEED = 3.2;       // units/sec
const whereEl=document.getElementById('where');
let walkPhase=0, lastLabel='';

function frame(now){
  requestAnimationFrame(frame);
  const dt = Math.min(0.05, (frame._p ? (now-frame._p)/1000 : 0)); frame._p = now;

  // turn the camera with left/right
  if(wantLeft()) camOffset += 1.6*dt;
  if(wantRight()) camOffset -= 1.6*dt;

  // walk along path
  let moving=false;
  if(wantFwd()){ s = Math.min(TOTAL, s + SPEED*dt); moving=true; }
  else if(wantBack()){ s = Math.max(0, s - SPEED*dt); moving=true; }

  const info = at(s);
  student.position.copy(info.pos);
  // face along the path (flattened); the camera follows behind this heading
  const flat = new THREE.Vector3(info.tan.x, 0, info.tan.z);
  if(flat.lengthSq() > 1e-5){ flat.normalize(); heading = Math.atan2(flat.x, flat.z); student.rotation.y = heading; }
  // leg/arm swing + footsteps while moving (not during the vertical elevator ride)
  const u=student.userData;
  if(moving && !info.isVertical){
    walkPhase += dt*9;
    const sw=Math.sin(walkPhase)*0.5;
    u.legL.rotation.x=sw; u.legR.rotation.x=-sw; u.armL.rotation.x=-sw; u.armR.rotation.x=sw;
    stepClock+=dt; if(stepClock>0.32){ stepClock=0; footstep(); }
  } else {
    u.legL.rotation.x*=0.8; u.legR.rotation.x*=0.8; u.armL.rotation.x*=0.8; u.armR.rotation.x*=0.8;
    if(!moving) stepClock=0.3;
  }

  // location label
  const label = LABELS[Math.min(LABELS.length-1, info.seg + (at(s).tan ? 0:0))] || '';
  const lbl = info.isVertical ? 'Elevator → 2nd floor' : label;
  if(lbl!==lastLabel){ whereEl.textContent=lbl; lastLabel=lbl; }

  const head = student.position.clone(); head.y += 1.5;
  placeCamera(head);
  renderer.render(scene, camera);
}

function resize(){ const w=canvas.clientWidth, h=canvas.clientHeight; renderer.setSize(w,h,false); camera.aspect=w/h; camera.updateProjectionMatrix(); }
addEventListener('resize', resize);

// ---------- load model ----------
new GLTFLoader().loadAsync(MODEL).then(gltf=>{
  scene.add(gltf.scene);
  document.getElementById('loading').remove();
  resize();
  requestAnimationFrame(frame);
}).catch(err=>{
  document.getElementById('loading').textContent = 'Could not load the building model: '+err;
  console.error(err);
});
