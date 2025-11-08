import 'package:northstar/services/io/io_service.dart';

import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import 'package:northstar/_server/router/sync_router.dart';
import 'package:northstar/_server/router/backup_router.dart';

import 'package:northstar/_server/router/util_router.dart';

Router createRootRouter(){
  final rootRouter = Router();

  // 响应静态资源
  final staticHandler = createStaticHandler(IoService.appDir);
  rootRouter.get("/static/<ignored|.*>", staticHandler);

  // 数据备份/同步
  rootRouter.mount("/backup", createBackupRouter().call);
  rootRouter.mount("/sync", createSyncRouter().call);

  rootRouter.mount("/util", createUtilRouter().call);

  return rootRouter;
}
