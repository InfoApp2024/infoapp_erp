// lib/pages/staff/models/staff_response_models.dart

import 'staff_model.dart'; // Asumiendo que StaffModel está en staff_model.dart

/// Respuesta de lista de empleados con paginación
class StaffResponse {
  final List<StaffModel> staff;
  final PaginationData pagination;
  final StaffSummary? summary;
  final StaffStatsData? stats;

  const StaffResponse({
    required this.staff,
    required this.pagination,
    this.summary,
    this.stats,
  });

  factory StaffResponse.fromJson(Map<String, dynamic> json) {
    return StaffResponse(
      staff:
          json['staff'] != null
              ? (json['staff'] as List)
                  .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
                  .toList()
              : [],
      pagination: PaginationData.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
      summary:
          json['summary'] != null
              ? StaffSummary.fromJson(json['summary'] as Map<String, dynamic>)
              : null,
      stats:
          json['stats'] != null
              ? StaffStatsData.fromJson(json['stats'] as Map<String, dynamic>)
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'staff': staff.map((e) => e.toJson()).toList(),
    'pagination': pagination.toJson(),
    'summary': summary?.toJson(),
    'stats': stats?.toJson(),
  };
}

/// Datos de paginación
class PaginationData {
  final int totalRecords;
  final int totalPages;
  final int currentPage;
  final int limit;
  final int offset;
  final bool hasNext;
  final bool hasPrev;

  const PaginationData({
    required this.totalRecords,
    required this.totalPages,
    required this.currentPage,
    required this.limit,
    required this.offset,
    required this.hasNext,
    required this.hasPrev,
  });

  factory PaginationData.fromJson(Map<String, dynamic> json) {
    return PaginationData(
      totalRecords: json['total_records'] ?? 0,
      totalPages: json['total_pages'] ?? 0,
      currentPage: json['current_page'] ?? 1,
      limit: json['limit'] ?? 20,
      offset: json['offset'] ?? 0,
      hasNext: json['has_next'] ?? false,
      hasPrev: json['has_prev'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_records': totalRecords,
    'total_pages': totalPages,
    'current_page': currentPage,
    'limit': limit,
    'offset': offset,
    'has_next': hasNext,
    'has_prev': hasPrev,
  };
}

/// Resumen de la consulta
class StaffSummary {
  final int totalReturned;
  final bool filtersApplied;
  final String sortBy;
  final String sortOrder;

  const StaffSummary({
    required this.totalReturned,
    required this.filtersApplied,
    required this.sortBy,
    required this.sortOrder,
  });

  factory StaffSummary.fromJson(Map<String, dynamic> json) {
    return StaffSummary(
      totalReturned: json['total_returned'] ?? 0,
      filtersApplied: json['filters_applied'] ?? false,
      sortBy: json['sort_by'] ?? 'first_name',
      sortOrder: json['sort_order'] ?? 'ASC',
    );
  }

  Map<String, dynamic> toJson() => {
    'total_returned': totalReturned,
    'filters_applied': filtersApplied,
    'sort_by': sortBy,
    'sort_order': sortOrder,
  };
}

/// Estadísticas de empleados
class StaffStatsData {
  final int totalStaff;
  final int activeStaff;
  final int inactiveStaff;
  final int departmentsCount;
  final int positionsCount;
  final double? averageSalary;
  final double? minSalary;
  final double? maxSalary;
  final int staffWithSalary;

  const StaffStatsData({
    required this.totalStaff,
    required this.activeStaff,
    required this.inactiveStaff,
    required this.departmentsCount,
    required this.positionsCount,
    this.averageSalary,
    this.minSalary,
    this.maxSalary,
    required this.staffWithSalary,
  });

  factory StaffStatsData.fromJson(Map<String, dynamic> json) {
    return StaffStatsData(
      totalStaff: json['total_staff'] ?? 0,
      activeStaff: json['active_staff'] ?? 0,
      inactiveStaff: json['inactive_staff'] ?? 0,
      departmentsCount: json['departments_count'] ?? 0,
      positionsCount: json['positions_count'] ?? 0,
      averageSalary: json['average_salary']?.toDouble(),
      minSalary: json['min_salary']?.toDouble(),
      maxSalary: json['max_salary']?.toDouble(),
      staffWithSalary: json['staff_with_salary'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_staff': totalStaff,
    'active_staff': activeStaff,
    'inactive_staff': inactiveStaff,
    'departments_count': departmentsCount,
    'positions_count': positionsCount,
    'average_salary': averageSalary,
    'min_salary': minSalary,
    'max_salary': maxSalary,
    'staff_with_salary': staffWithSalary,
  };
}

/// Estadísticas del movimiento de empleados
class MovementStats {
  final int totalIn;
  final int totalOut;
  final int totalCurrent;
  final double turnoverRate;
  final List<MonthlyMovement> monthlyData;

  const MovementStats({
    required this.totalIn,
    required this.totalOut,
    required this.totalCurrent,
    required this.turnoverRate,
    required this.monthlyData,
  });

  factory MovementStats.fromJson(Map<String, dynamic> json) {
    return MovementStats(
      totalIn: json['total_in'] ?? 0,
      totalOut: json['total_out'] ?? 0,
      totalCurrent: json['total_current'] ?? 0,
      turnoverRate: (json['turnover_rate'] ?? 0.0).toDouble(),
      monthlyData:
          json['monthly_data'] != null
              ? (json['monthly_data'] as List)
                  .map(
                    (e) => MonthlyMovement.fromJson(e as Map<String, dynamic>),
                  )
                  .toList()
              : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'total_in': totalIn,
    'total_out': totalOut,
    'total_current': totalCurrent,
    'turnover_rate': turnoverRate,
    'monthly_data': monthlyData.map((e) => e.toJson()).toList(),
  };
}

/// Movimiento mensual
class MonthlyMovement {
  final String month;
  final int hires;
  final int departures;
  final int netChange;

  const MonthlyMovement({
    required this.month,
    required this.hires,
    required this.departures,
    required this.netChange,
  });

  factory MonthlyMovement.fromJson(Map<String, dynamic> json) {
    return MonthlyMovement(
      month: json['month'] ?? '',
      hires: json['hires'] ?? 0,
      departures: json['departures'] ?? 0,
      netChange: json['net_change'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'month': month,
    'hires': hires,
    'departures': departures,
    'net_change': netChange,
  };
}

/// Estadísticas del dashboard
class DashboardStats {
  final StaffStatsData staffStats;
  final MovementStats movementStats;
  final List<DepartmentStats> departmentStats;
  final List<Map<String, dynamic>>? chartData;
  final Map<String, dynamic>? trends;

  const DashboardStats({
    required this.staffStats,
    required this.movementStats,
    required this.departmentStats,
    this.chartData,
    this.trends,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      staffStats: StaffStatsData.fromJson(
        json['staff_stats'] as Map<String, dynamic>,
      ),
      movementStats: MovementStats.fromJson(
        json['movement_stats'] as Map<String, dynamic>,
      ),
      departmentStats:
          json['department_stats'] != null
              ? (json['department_stats'] as List)
                  .map(
                    (e) => DepartmentStats.fromJson(e as Map<String, dynamic>),
                  )
                  .toList()
              : [],
      chartData:
          json['chart_data'] != null
              ? List<Map<String, dynamic>>.from(json['chart_data'])
              : null,
      trends: json['trends'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'staff_stats': staffStats.toJson(),
    'movement_stats': movementStats.toJson(),
    'department_stats': departmentStats.map((e) => e.toJson()).toList(),
    'chart_data': chartData,
    'trends': trends,
  };
}

/// Estadísticas por departamento
class DepartmentStats {
  final String departmentId;
  final String departmentName;
  final int totalStaff;
  final int activeStaff;
  final int inactiveStaff;
  final double? averageSalary;
  final double averageYearsEmployed;

  const DepartmentStats({
    required this.departmentId,
    required this.departmentName,
    required this.totalStaff,
    required this.activeStaff,
    required this.inactiveStaff,
    this.averageSalary,
    required this.averageYearsEmployed,
  });

  factory DepartmentStats.fromJson(Map<String, dynamic> json) {
    return DepartmentStats(
      departmentId: json['department_id']?.toString() ?? '',
      departmentName: json['department_name'] ?? '',
      totalStaff: json['total_staff'] ?? 0,
      activeStaff: json['active_staff'] ?? 0,
      inactiveStaff: json['inactive_staff'] ?? 0,
      averageSalary: json['average_salary']?.toDouble(),
      averageYearsEmployed: (json['average_years_employed'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'department_id': departmentId,
    'department_name': departmentName,
    'total_staff': totalStaff,
    'active_staff': activeStaff,
    'inactive_staff': inactiveStaff,
    'average_salary': averageSalary,
    'average_years_employed': averageYearsEmployed,
  };
}
