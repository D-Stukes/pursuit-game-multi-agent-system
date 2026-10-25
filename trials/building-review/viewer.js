import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';

const $=s=>document.querySelector(s),viewport=$('#viewport'),status=$('#status');
const convert=p=>new THREE.Vector3(p[0],p[2],-p[1]);
let renderer,controls,scene,camera,model,meta,activeLayer='building',activeStop=0;
let modelMeshes=[],routeLines=[],currentReset=null,selectionRequest=0;
const sceneState=document.body.dataset;
const setStatus=text=>{status.textContent=text;};
function render(){if(renderer&&!$('#model-panel').hidden)renderer.render(scene,camera);}
function showViewport(){if(matchMedia('(max-width:680px)').matches)viewport.scrollIntoView({block:'start',behavior:'instant'});}
function resize(){if(!renderer||$('#model-panel').hidden)return;const width=viewport.clientWidth,height=viewport.clientHeight;renderer.setSize(width,height,false);camera.aspect=width/height;camera.updateProjectionMatrix();render();}
window.addEventListener('viewer-resize',resize);
new ResizeObserver(resize).observe(viewport);

function moveCamera(position,target,fov=50){camera.position.copy(convert(position));controls.target.copy(convert(target));camera.fov=fov;camera.updateProjectionMatrix();controls.update();render();}
function routeVisibility(){
 for(const item of routeLines)item.line.visible=$('#route').checked&&activeLayer!=='classroom'&&(activeLayer==='building'||item.layer===activeLayer);
}
function applyVisibility(){
 if(!model)return;
 model.visible=true;
 const cut=$('#ceilings').checked;
 renderer.clippingPlanes=activeLayer==='ground'?[new THREE.Plane(new THREE.Vector3(0,-1,0),4.80)]:[];
 for(const item of modelMeshes)item.object.visible=(activeLayer==='building'||item.layer===activeLayer)&&!(cut&&item.ceiling);
 $('#ceilings').disabled=false;
 $('#route').disabled=false;
 for(const button of document.querySelectorAll('[data-layer]'))button.setAttribute('aria-pressed',String(button.dataset.layer===activeLayer));
 routeVisibility();
 sceneState.layer=activeLayer;
 sceneState.visibleMeshes=String(modelMeshes.filter(x=>x.object.visible&&model.visible).length);
 sceneState.classroomVisible=String(modelMeshes.some(x=>x.room==='classroom'&&x.object.visible));
 render();
}
function note(title,message,floor){$('#view-title').textContent=title;$('#view-note').textContent=message;$('#floor-label').textContent=floor;}
function markStop(index){
 activeStop=index;
 for(const button of document.querySelectorAll('[data-stop]')){
  if(Number(button.dataset.stop)===index)button.setAttribute('aria-current','step');else button.removeAttribute('aria-current');
 }
 $('#previous').disabled=index<=0;$('#next').disabled=index<0||index>=meta.stops.length-1;
 sceneState.stop=index<0?'overview':meta.stops[index].id;
}
function goStop(index){
 const stop=meta.stops[index];if(!stop)return;
 selectionRequest++;
 activeLayer=stop.layer;$('#ceilings').checked=Boolean(stop.cutaway);applyVisibility();
 moveCamera(stop.position,stop.target,stop.fov);markStop(index);note(stop.label,stop.note,stop.floor);
 currentReset=()=>goStop(index);setStatus('Drag to inspect, or choose the next stop.');showViewport();
}
async function floorView(layer){
 ++selectionRequest;
 if(layer==='building'){goStop(0);return;}
 if(layer==='classroom'){
  goStop(meta.stops.findIndex(x=>x.id==='classroom'));return;
 }
 activeLayer=layer;$('#ceilings').checked=true;applyVisibility();markStop(-1);
 if(layer==='ground'){
  moveCamera([17,-15,23],[-1,6.4,1.2],49);note('Ground-floor cutaway','Street entry, stairs and right ramp, separate brown-door room, larger left area and the right-facing elevators.','Ground floor');
 }else{
  moveCamera([52,-30,52],[6,18,5.8],48);note('Second-floor cutaway','The fixed elevator bank opens to a landing and cross-hall before reception. Existing rooms are repositioned together; their interiors and door connections are retained.','Second floor');
 }
 currentReset=()=>floorView(layer);setStatus('Ceilings are hidden for this cutaway. Drag to rotate the floor.');render();showViewport();
}
function addRoutes(){
 for(const route of meta.routes){
  const layer=route.points[0][2]>4.5?'upper':'ground';
  const points=route.points.map(p=>convert([p[0],p[1],p[2]+.075]));
  const geometry=new THREE.BufferGeometry().setFromPoints(points);
  const line=new THREE.Line(geometry,new THREE.LineBasicMaterial({color:layer==='upper'?0xeebc6e:0x087d95,depthTest:false}));line.renderOrder=10;line.visible=false;scene.add(line);routeLines.push({line,layer});
 }
}
try{
 meta=await (await fetch('scene.json',{cache:'no-store'})).json();
 renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance'});renderer.setPixelRatio(Math.min(window.devicePixelRatio,1.6));renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.05;
 renderer.domElement.setAttribute('aria-label','Pursuit interactive model');viewport.appendChild(renderer.domElement);
 scene=new THREE.Scene();scene.background=new THREE.Color(0xb8c2c9);
 camera=new THREE.PerspectiveCamera(50,1,.03,250);
 controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=false;controls.minDistance=.15;controls.maxDistance=140;controls.listenToKeyEvents(viewport);controls.addEventListener('change',render);
 const pmrem=new THREE.PMREMGenerator(renderer),room=new RoomEnvironment();const environment=pmrem.fromScene(room,.04);scene.environment=environment.texture;scene.environmentIntensity=.8;room.dispose();pmrem.dispose();
 scene.add(new THREE.HemisphereLight(0xffffff,0xc4cad1,2.0));
 const sunlight=new THREE.DirectionalLight(0xffffff,2.2);sunlight.position.set(-15,30,18);scene.add(sunlight);
 const fill=new THREE.DirectionalLight(0xdcecff,1.1);fill.position.set(20,10,-15);scene.add(fill);
 const gltf=await new GLTFLoader().loadAsync(meta.model+'?v='+meta.model_sha256,event=>{if(event.total)setStatus(`Loading building: ${Math.round(event.loaded/event.total*100)}%`);});
 model=gltf.scene;scene.add(model);model.updateMatrixWorld(true);
 let unmapped=0;
 model.traverse(object=>{
  if(!object.isMesh)return;
  let owner=object,record;
  while(owner&&!record){record=meta.meshes[owner.userData.name||owner.name];if(!record)owner=owner.parent;}
  if(!record){unmapped++;const box=new THREE.Box3().setFromObject(object);record={layer:box.min.y>=4.75?'upper':'ground',ceiling:false};}
  modelMeshes.push({object,...record});
 });
 sceneState.modelLoaded='true';sceneState.modelHash=meta.model_sha256;sceneState.meshCount=String(modelMeshes.length);sceneState.unmappedMeshes=String(unmapped);
 addRoutes();
 meta.stops.forEach((stop,index)=>{
  const item=document.createElement('li'),button=document.createElement('button');button.type='button';button.dataset.stop=String(index);button.textContent=stop.label;button.addEventListener('click',()=>goStop(index));item.appendChild(button);$('#stops').appendChild(item);
 });
 document.querySelectorAll('[data-layer]').forEach(button=>{button.disabled=false;button.addEventListener('click',()=>floorView(button.dataset.layer));});
 $('#previous').addEventListener('click',()=>goStop(activeStop-1));$('#next').addEventListener('click',()=>goStop(activeStop+1));
 $('#ceilings').addEventListener('change',applyVisibility);$('#route').addEventListener('change',()=>{routeVisibility();render();});
 $('#reset').disabled=false;$('#reset').addEventListener('click',()=>currentReset?.());
 $('#route').disabled=false;$('#loading').hidden=true;goStop(0);resize();
 if(unmapped)setStatus('Model loaded; some cutaway labels could not be mapped. Some floor cutaways may be incomplete.');
}catch(error){
 sceneState.modelLoaded='false';$('#loading').textContent='3D could not start. Check that WebGL is enabled, then reload this page.';status.classList.add('error');setStatus('3D unavailable. Download the GLB below to inspect it in a compatible 3D application.');console.error('Pursuit viewer load failed:',error);
}
