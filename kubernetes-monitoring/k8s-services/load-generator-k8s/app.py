import asyncio
import aiohttp
import time
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class K8sLoadGenerator:
    def __init__(self):
        self.target_service = "http://banking-service.banking-k8s-test.svc.cluster.local"
        self.requests_per_second = 50
        self.concurrent_workers = 10
        self.running = True

    async def make_request(self, session, worker_id):
        """Make a single HTTP request to the banking service"""
        try:
            async with session.get(f"{self.target_service}/") as response:
                status = response.status
                if worker_id % 10 == 0:  # Log every 10th worker
                    logger.info(f"Worker {worker_id}: Status {status}")
                return status == 200
        except Exception as e:
            if worker_id % 10 == 0:
                logger.error(f"Worker {worker_id}: Request failed - {e}")
            return False

    async def worker(self, worker_id, session):
        """Individual worker that generates continuous load"""
        request_count = 0
        success_count = 0

        while self.running:
            try:
                success = await self.make_request(session, worker_id)
                request_count += 1
                if success:
                    success_count += 1

                # Log stats every 100 requests per worker
                if request_count % 100 == 0:
                    success_rate = (success_count / request_count) * 100
                    logger.info(
                        f"Worker {worker_id}: {request_count} requests, {success_rate:.1f}% success rate")

                # Control request rate
                await asyncio.sleep(1.0 / (self.requests_per_second / self.concurrent_workers))

            except asyncio.CancelledError:
                logger.info(f"Worker {worker_id}: Cancelled")
                break
            except Exception as e:
                logger.error(f"Worker {worker_id}: Unexpected error - {e}")
                await asyncio.sleep(1)

    async def run_load_test(self):
        """Run the load test with multiple concurrent workers"""
        logger.info(f"Starting load test against {self.target_service}")
        logger.info(
            f"Target: {self.requests_per_second} requests/second with {self.concurrent_workers} workers")

        timeout = aiohttp.ClientTimeout(total=5)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            # Create worker tasks
            tasks = []
            for i in range(self.concurrent_workers):
                task = asyncio.create_task(self.worker(i, session))
                tasks.append(task)

            try:
                # Run workers indefinitely
                await asyncio.gather(*tasks)
            except KeyboardInterrupt:
                logger.info("Stopping load test...")
                self.running = False

                # Cancel all tasks
                for task in tasks:
                    task.cancel()

                # Wait for tasks to complete
                await asyncio.gather(*tasks, return_exceptions=True)


if __name__ == "__main__":
    load_generator = K8sLoadGenerator()

    try:
        asyncio.run(load_generator.run_load_test())
    except KeyboardInterrupt:
        print("\nLoad test stopped by user")
