template < int ignoreAdetection > __global__ void MCd(MemStruct);
__device__ float rand_MWC_oc(unsigned long long * , unsigned int * );
__device__ float rand_MWC_co(unsigned long long * , unsigned int * );
__device__ void LaunchPhoton(PhotonStruct * , unsigned long long * , unsigned int * );
__global__ void LaunchPhoton_Global(MemStruct);
__device__ void Spin(PhotonStruct * , float, unsigned long long * , unsigned int * );
__device__ unsigned int Reflect(PhotonStruct * , int, unsigned long long * , unsigned int * );
__device__ unsigned int PhotonSurvive(PhotonStruct * , unsigned long long * , unsigned int * );
__device__ void AtomicAddULL(unsigned long long * address, unsigned int add);

__device__ void LaunchPhoton(PhotonStruct * p, unsigned long long * x, unsigned int * a) {
  p -> x = 0.0f;
  p -> y = 0.0f;
  p -> z = 0.0f;
  p -> dx = 0.0f;
  p -> dy = 0.0f;
  p -> dz = 1.0f;
  p -> layer = 1;
  p -> weight = * start_weight_dc;
}

__global__ void LaunchPhoton_Global(MemStruct DeviceMem) {
  int bx = blockIdx.x;
  int tx = threadIdx.x;
  int init = NUM_THREADS_PER_BLOCK * bx;

  PhotonStruct p;
  unsigned long long int x = DeviceMem.x[init + tx]; 
  unsigned int a = DeviceMem.a[init + tx]; 

  LaunchPhoton( & p, & x, & a);

  DeviceMem.p[init + tx] = p; 
}

__device__ void Spin(PhotonStruct * p, float g, unsigned long long * x, unsigned int * a) {
  float cost, sint; // cosine and sine of the polar deflection angle theta
  float cosp, sinp; // cosine and sine of the azimuthal angle psi. 
  float temp;

  float tempdir = p -> dx;

  temp = __fdividef((1.0f - (g) * (g)), (1.0f - (g) + 2.0f * (g) * rand_MWC_co(x, a)));
  cost = __fdividef((1.0f + (g) * (g) - temp * temp), (2.0f * (g)));
  if (g == 0.0f)
    cost = 2.0f * rand_MWC_co(x, a) - 1.0f;

  sint = sqrtf(1.0f - cost * cost);

  __sincosf(2.0f * PI * rand_MWC_co(x, a), & sinp, & cosp);

  temp = sqrtf(1.0f - p -> dz * p -> dz);

  if (temp == 0.0f) {
    //normal incident.
    p -> dx = sint * cosp;
    p -> dy = sint * sinp;
    p -> dz = copysignf(cost, p -> dz * cost);
  } else {
    // regular incident.
    p -> dx = __fdividef(sint * (p -> dx * p -> dz * cosp - p -> dy * sinp), temp) + p -> dx * cost;
    p -> dy = __fdividef(sint * (p -> dy * p -> dz * cosp + tempdir * sinp), temp) + p -> dy * cost;
    p -> dz = -sint * cosp * temp + p -> dz * cost;
  }

  temp = rsqrtf(p -> dx * p -> dx + p -> dy * p -> dy + p -> dz * p -> dz);
  p -> dx = p -> dx * temp;
  p -> dy = p -> dy * temp;
  p -> dz = p -> dz * temp;
}