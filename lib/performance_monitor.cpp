#include "performance_monitor.h"

const std::string performance_monitor::flops_event_name("FP_ARITH_INST_RETIRED_256B_PACKED_SINGLE");
const std::string performance_monitor::mflops_metric_name = "AVX SP [MFLOP/s]";
const std::string performance_monitor::mflops_dp_metric_name = "AVX DP [MFLOP/s]";
const std::string performance_monitor::l2_bandwidth_metric_name = "L2 bandwidth [MBytes/s]";
const std::string performance_monitor::l3_bandwidth_metric_name = "L3 bandwidth [MBytes/s]";
const std::string performance_monitor::ram_bandwidth_metric_name = "Memory bandwidth [MBytes/s]";

const std::string performance_monitor::likwidOutputFilepath = "/tmp/test_marker.out";
const std::string performance_monitor::jsonResultOutputFilepath = "./perfmon_output.json";
const std::string performance_monitor::accessmode = ACCESSMODE_DAEMON;

std::map<std::string, double> performance_monitor::runtimes_by_tag;
int performance_monitor::num_threads;
float performance_monitor::num_flops;
float performance_monitor::mflops;
float performance_monitor::mflops_saturation;
float performance_monitor::mflops_dp;
float performance_monitor::mflops_dp_saturation;
float performance_monitor::l2_bw;
float performance_monitor::l2_bw_saturation;
float performance_monitor::l3_bw;
float performance_monitor::l3_bw_saturation;
float performance_monitor::ram_bw;
float performance_monitor::ram_bw_saturation;

void performance_monitor::init(){
  init("FLOPS_SP|MEM_DP|L3|L2");
}

void performance_monitor::init(const char * event_group)
{
  remove(likwidOutputFilepath.c_str());
  // TODO: use omp_get_thread_nums() to build string for LIKWID_THREADS

  setenv("LIKWID_EVENTS", event_group, 1);
  setenv("LIKWID_MODE", accessmode.c_str(), 1);
  setenv("LIKWID_FILEPATH", likwidOutputFilepath.c_str(), 1); // output filepath
  // unfortunately, this likwid_threads envvar is absolutely necessary
  setenv("LIKWID_THREADS", "0,1,2,3", 1); // list of threads
  // forces likwid to take control of registers even if they are in use
  setenv("LIKWID_FORCE", "1", 1);

  // likwid marker init reads the environment variables above
  likwid_markerInit();

#pragma omp parallel
  {
    // Brandon's code includdes the comment "Read on mailing list dont need to
    // do this unless not already pinning" above the call to
    // likwid_markerThreadInit. I cannot find anything like this in the mailing
    // list... what does it mean?

    // Init marker api for current thread
    likwid_markerThreadInit(); 

    // optionally pin each thread to single core
    likwid_pinThread(omp_get_thread_num()); 

    num_threads = omp_get_num_threads();
  }

  perfmon_startCounters();

  printf("Thread count initialized to %d\n", num_threads);
  printf("Number of groups setup: %d\n", perfmon_getNumberOfGroups());
}

void performance_monitor::startRegion(const char * tag)
{
  // about 'likwid_markerRegisterRegion: 

  // optional according to
  // https://github.com/RRZE-HPC/likwid/wiki/TutorialMarkerC

  // BUT highly recommended when using accessD according to
  // https://github.com/RRZE-HPC/likwid/wiki/likwid-perfctr#using-the-marker-api

  likwid_markerRegisterRegion(tag);

  likwid_markerStartRegion(tag);
}

void performance_monitor::stopRegion(const char * tag)
{
  likwid_markerStopRegion(tag);

  int nevents = 20;
  double events[nevents];
  double time;
  int count;

  LIKWID_MARKER_GET(tag, &nevents, events, &time, &count);
  printf("Tag %s: Thread %d got %d events, runtime %f s, call count %d\n",
         tag, omp_get_thread_num(), nevents, time, count);
  // std::string s(tag);
  if(runtimes_by_tag.count(tag)){
    runtimes_by_tag[tag] = fmax(runtimes_by_tag[tag], time);
  } else {
    runtimes_by_tag[tag] = time;
  }
}

void performance_monitor::close(){
  perfmon_stopCounters();
  likwid_markerClose();
}

void performance_monitor::getAggregateResults(){
  int gid;
  float event_value, metric_value;
  const char * event_name, * metric_name;

  num_flops = 0.;
  mflops = 0.;
  mflops_dp = 0.;
  l2_bw = 0.;
  l3_bw = 0.;
  ram_bw = 0.;

  perfmon_readMarkerFile(likwidOutputFilepath.c_str());

  for (int t = 0; t < num_threads; t++)
  {
    for (int i = 0; i < perfmon_getNumberOfRegions(); i++)
    {
      gid = perfmon_getGroupOfRegion(i);
      for (int k = 0; k < perfmon_getEventsOfRegion(i); k++){
        event_name = perfmon_getEventName(gid, k);
        event_value = perfmon_getResultOfRegionThread(i, k, t);
        if(flops_event_name.compare(event_name) == 0 &&
           event_value > 0){
          num_flops += event_value;
        }
      }
      for (int k = 0; k < perfmon_getNumberOfMetrics(gid); k++){
        metric_name = perfmon_getMetricName(gid, k);
        metric_value = perfmon_getMetricOfRegionThread(i, k, t);
        if(!isnan(metric_value)){
          if(mflops_metric_name.compare(metric_name) == 0){
            mflops += metric_value;
          }
          else if(mflops_dp_metric_name.compare(metric_name) == 0){
            mflops_dp += metric_value;
          }
          else if(l2_bandwidth_metric_name.compare(metric_name) == 0){
            l2_bw += metric_value;
          }
          else if(l3_bandwidth_metric_name.compare(metric_name) == 0){
            l3_bw += metric_value;
          }
          else if(ram_bandwidth_metric_name.compare(metric_name) == 0){
            ram_bw += metric_value;
          }
        }
      }
    }
  }
}

void performance_monitor::compareActualWithbench()
{
  getAggregateResults();
  mflops_saturation = mflops/EXPERIENTIAL_SP_RATE_MFLOPS;
  // mflops_dp_saturation = mflops/EXPERIENTIAL_DP_RATE_MFLOPS;
  // l1_bw_saturation = l1_bw/EXPERIENTIAL_RW_BW_L1;
  l2_bw_saturation = l2_bw/EXPERIENTIAL_RW_BW_L2;
  l3_bw_saturation = l3_bw/EXPERIENTIAL_RW_BW_L3;
  ram_bw_saturation = ram_bw/EXPERIENTIAL_RW_BW_RAM;
}

void performance_monitor::printResults()
{
  printDetailedResults();
  printOnlyAggregate();
  printComparison();
}

void performance_monitor::printDetailedResults()
{
  int gid;
  float event_value, metric_value;
  const char * event_name, * counter_name, * metric_name;

  printf("----- begin performance_monitor report -----\n");
  perfmon_readMarkerFile(likwidOutputFilepath.c_str());
  printf("\nMarker API measured %d regions\n", perfmon_getNumberOfRegions());
  for (int i = 0; i < perfmon_getNumberOfRegions(); i++)
  {
    gid = perfmon_getGroupOfRegion(i);
    printf("Region %s with %d events and %d metrics\n", perfmon_getTagOfRegion(i),
           perfmon_getEventsOfRegion(i),
           perfmon_getMetricsOfRegion(i));
  }

  for (int t = 0; t < num_threads; t++)
  {
    printf("\nMetrics output for hardware thread %d\n", t);

    for (int i = 0; i < perfmon_getNumberOfRegions(); i++)
    {
      gid = perfmon_getGroupOfRegion(i);
      printf("Region %s with gid %d\n", perfmon_getTagOfRegion(i), gid);
      for (int k = 0; k < perfmon_getEventsOfRegion(i); k++){
        event_name = perfmon_getEventName(gid, k);
        counter_name = perfmon_getCounterName(gid, k);
        event_value = perfmon_getResultOfRegionThread(i, k, t);
        printf("Event %s:%s: %.3f\n", event_name, counter_name, event_value);
      }
      for (int k = 0; k < perfmon_getNumberOfMetrics(gid); k++){
        metric_name = perfmon_getMetricName(gid, k);
        metric_value = perfmon_getMetricOfRegionThread(i, k, t);
        printf("Metric %s: %.3f\n", metric_name, metric_value);
      }
      printf("\n");
    }
  }
}

void performance_monitor::printOnlyAggregate()
{
  getAggregateResults();

  printf("----- begin aggregate performance_monitor report -----\n");
  std::cout << "results_by_tag size: " + std::to_string(runtimes_by_tag.size())
             + "\n";
  for (std::map<std::string, double>::iterator it=runtimes_by_tag.begin(); 
       it!=runtimes_by_tag.end(); ++it){
    std::cout << "Runtime for " + it->first + ": "
               + std::to_string(it->second) + "\n";
  }
  printf("\n-- computation --\n");
  printf("Aggregate %s: %.3e\n", flops_event_name.c_str(), num_flops);
  printf("Total FP ops: %.3e\n", num_flops * OPS_PER_VECTOR);
  printf("\n-- computation rates --\n");
  printf("Aggregate %s: %.3f\n", mflops_metric_name.c_str(), mflops);
  printf("Aggregate %s: %.3f\n", mflops_dp_metric_name.c_str(), mflops_dp);
  // printf("Total TFlop/s: %.3f\n", mflops*MFLOPS_TO_TFLOPS);
  printf("\n-- memory --\n");
  printf("Aggregate %s: %.3f\n", l2_bandwidth_metric_name.c_str(), l2_bw);
  printf("Aggregate %s: %.3f\n", l3_bandwidth_metric_name.c_str(), l3_bw);
  printf("Aggregate %s: %.3f\n", ram_bandwidth_metric_name.c_str(), ram_bw);
  printf("----- end performance_monitor report -----\n");
  printf("\n");
}

void performance_monitor::printComparison(){
  compareActualWithbench();
  printf("----- begin saturation level performance_monitor report -----\n");
  printf("Percentage of available SP flop performance used: %.3f\n",
         mflops_saturation);
  // printf("Percentage of available DP flop performance used: %.3f\n",
  //        mflops_dp_saturation);
  // printf("Percentage of available L1 bandwidth used: %.3f\n",
  //        l1_bw_saturation);
  printf("Percentage of available L2 bandwidth used: %.3f\n",
         l2_bw_saturation);
  printf("Percentage of available L3 bandwidth used: %.3f\n",
         l3_bw_saturation);
  printf("Percentage of available RAM bandwidth used: %.3f\n",
         ram_bw_saturation);
  printf("----- end saturation level performance_monitor report -----\n");
  printf("\n");
}

float performance_monitor::getMFlops(){
  return mflops;
}

void performance_monitor::resultsToJson(){

}
