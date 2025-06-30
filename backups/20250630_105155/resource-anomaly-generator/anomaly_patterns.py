"""
Resource Anomaly Pattern Definitions
Defines various resource anomaly patterns for testing container optimization
"""
import time
import threading
import psutil
import logging
from abc import ABC, abstractmethod

logger = logging.getLogger(__name__)

class AnomalyPattern(ABC):
    """Base class for anomaly patterns"""
    
    def __init__(self):
        self.is_running = False
        self.thread = None
        
    @abstractmethod
    def generate(self):
        """Generate the anomaly pattern"""
        pass
    
    def start(self):
        """Start generating anomaly"""
        if self.is_running:
            logger.warning(f"{self.__class__.__name__} already running")
            return
        
        self.is_running = True
        self.thread = threading.Thread(target=self._run)
        self.thread.daemon = True
        self.thread.start()
        logger.info(f"Started {self.__class__.__name__}")
    
    def stop(self):
        """Stop generating anomaly"""
        self.is_running = False
        if self.thread:
            self.thread.join(timeout=5)
        logger.info(f"Stopped {self.__class__.__name__}")
    
    def _run(self):
        """Run the anomaly generation"""
        while self.is_running:
            try:
                self.generate()
            except Exception as e:
                logger.error(f"Error in {self.__class__.__name__}: {e}")
                time.sleep(1)

class MemoryLeakPattern(AnomalyPattern):
    """Simulates a memory leak"""
    
    def __init__(self, leak_rate_mb=10, max_leak_mb=500):
        super().__init__()
        self.leak_rate_mb = leak_rate_mb
        self.max_leak_mb = max_leak_mb
        self.leaked_data = []
        
    def generate(self):
        """Generate memory leak"""
        current_leak_mb = len(self.leaked_data) * self.leak_rate_mb / 1024
        
        if current_leak_mb < self.max_leak_mb:
            # Allocate more memory
            data = bytearray(self.leak_rate_mb * 1024 * 1024)
            self.leaked_data.append(data)
            logger.debug(f"Memory leak: {current_leak_mb:.1f}MB allocated")
        
        time.sleep(5)  # Leak every 5 seconds
    
    def stop(self):
        """Stop and cleanup"""
        super().stop()
        self.leaked_data.clear()  # Release memory

class CPUSpikePattern(AnomalyPattern):
    """Simulates CPU spikes"""
    
    def __init__(self, spike_duration=10, spike_intensity=0.8, interval=30):
        super().__init__()
        self.spike_duration = spike_duration
        self.spike_intensity = spike_intensity
        self.interval = interval
        
    def generate(self):
        """Generate CPU spike"""
        start_time = time.time()
        
        # CPU intensive operation
        while time.time() - start_time < self.spike_duration:
            if not self.is_running:
                break
            
            # Busy loop to consume CPU
            for _ in range(int(1000000 * self.spike_intensity)):
                _ = sum(i * i for i in range(100))
            
            # Brief pause to allow other threads
            time.sleep(0.001)
        
        logger.debug(f"CPU spike completed, waiting {self.interval}s")
        
        # Wait for next spike
        for _ in range(self.interval):
            if not self.is_running:
                break
            time.sleep(1)

class MemoryChurnPattern(AnomalyPattern):
    """Simulates high memory allocation/deallocation (churn)"""
    
    def __init__(self, churn_size_mb=50, churn_rate=10):
        super().__init__()
        self.churn_size_mb = churn_size_mb
        self.churn_rate = churn_rate
        
    def generate(self):
        """Generate memory churn"""
        allocations = []
        
        # Allocate
        for _ in range(self.churn_rate):
            data = bytearray(self.churn_size_mb * 1024 * 1024 // self.churn_rate)
            allocations.append(data)
            time.sleep(0.1)
        
        logger.debug(f"Memory churn: allocated {self.churn_size_mb}MB")
        
        # Hold briefly
        time.sleep(2)
        
        # Deallocate
        allocations.clear()
        logger.debug(f"Memory churn: deallocated {self.churn_size_mb}MB")
        
        # Pause before next churn
        time.sleep(3)

class ContainerRestartPattern(AnomalyPattern):
    """Simulates conditions that would trigger container restart"""
    
    def __init__(self, memory_threshold_percent=90):
        super().__init__()
        self.memory_threshold_percent = memory_threshold_percent
        self.memory_hog = []
        
    def generate(self):
        """Generate conditions for restart"""
        # Get current memory usage
        memory_info = psutil.virtual_memory()
        current_percent = memory_info.percent
        
        if current_percent < self.memory_threshold_percent:
            # Allocate more memory to reach threshold
            available_mb = memory_info.available / 1024 / 1024
            allocate_mb = int(available_mb * 0.3)  # Use 30% of available
            
            if allocate_mb > 0:
                try:
                    data = bytearray(allocate_mb * 1024 * 1024)
                    self.memory_hog.append(data)
                    logger.debug(f"Restart pattern: allocated {allocate_mb}MB, "
                               f"total usage: {psutil.virtual_memory().percent}%")
                except MemoryError:
                    logger.warning("Memory allocation failed")
        
        time.sleep(10)
    
    def stop(self):
        """Stop and cleanup"""
        super().stop()
        self.memory_hog.clear()

class IOIntensivePattern(AnomalyPattern):
    """Simulates I/O intensive operations"""
    
    def __init__(self, file_size_mb=10, operations_per_second=5):
        super().__init__()
        self.file_size_mb = file_size_mb
        self.operations_per_second = operations_per_second
        self.temp_file = '/tmp/io_test_file'
        
    def generate(self):
        """Generate I/O load"""
        data = bytearray(self.file_size_mb * 1024 * 1024)
        
        for _ in range(self.operations_per_second):
            if not self.is_running:
                break
            
            # Write
            try:
                with open(self.temp_file, 'wb') as f:
                    f.write(data)
                
                # Read
                with open(self.temp_file, 'rb') as f:
                    _ = f.read()
                
                logger.debug(f"I/O operation completed: {self.file_size_mb}MB")
            except Exception as e:
                logger.error(f"I/O error: {e}")
            
            time.sleep(1.0 / self.operations_per_second)

class ResourceFluctuationPattern(AnomalyPattern):
    """Simulates fluctuating resource usage"""
    
    def __init__(self):
        super().__init__()
        self.phase = 0
        self.data = []
        
    def generate(self):
        """Generate fluctuating resource usage"""
        self.phase = (self.phase + 1) % 4
        
        if self.phase == 0:
            # Low usage
            self.data.clear()
            time.sleep(10)
            
        elif self.phase == 1:
            # Ramp up
            for _ in range(5):
                self.data.append(bytearray(10 * 1024 * 1024))  # 10MB chunks
                time.sleep(2)
                
        elif self.phase == 2:
            # High usage with CPU
            for _ in range(100000):
                if not self.is_running:
                    break
                _ = sum(i * i for i in range(1000))
            time.sleep(5)
            
        else:
            # Ramp down
            while len(self.data) > 0:
                self.data.pop()
                time.sleep(2)

# Pattern registry
ANOMALY_PATTERNS = {
    'memory_leak': MemoryLeakPattern,
    'cpu_spike': CPUSpikePattern,
    'memory_churn': MemoryChurnPattern,
    'restart_trigger': ContainerRestartPattern,
    'io_intensive': IOIntensivePattern,
    'fluctuation': ResourceFluctuationPattern
}